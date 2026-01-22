return function(EspPage, BoxESPAPI)
	local Section = EspPage:Section({
		Name = "Box ESP",
		Description = "Draw boxes around players",
		Icon = "10709782497",
		Side = 1
	})

	Section:Toggle({
		Name = "Enable Box ESP",
		Flag = "BoxESPToggle",
		Default = false,
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({Enabled = Value})
			BoxESPAPI:Toggle(Value)
		end
	})

	-- ⭐ THÊM DROPDOWN MODE
	Section:Dropdown({
		Name = "Target Mode",
		Flag = "NPCModeDropdown",
		Options = {"Players", "NPCs", "Both"},
		Default = "Both",
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({NPCMode = Value})
		end
	})

	Section:Toggle({
		Name = "Show Self Box",
		Flag = "ShowSelfBox",
		Default = false,
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({ShowSelfBox = Value})
		end
	})

	Section:Toggle({
		Name = "Inner Border",
		Flag = "InnerBorder",
		Default = false,
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({ShowInnerBorder = Value})
		end
	})

	Section:Slider({
		Name = "Box Thickness",
		Flag = "BoxThickness",
		Min = 0.1,
		Max = 3,
		Default = 0.5,
		Decimals = 0.1,
		Suffix = "px",
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({BoxThickness = Value})
		end
	})

	Section:Slider({
		Name = "Inner Thickness",
		Flag = "InnerThickness",
		Min = 0.1,
		Max = 3,
		Default = 0.5,
		Decimals = 0.1,
		Suffix = "px",
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({InnerThickness = Value})
		end
	})

	Section:Toggle({
		Name = "Team Check",
		Flag = "TeamCheck",
		Default = false,
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({EnableTeamCheck = Value})
		end
	})

	Section:Toggle({
		Name = "Enemy Only",
		Flag = "EnemyOnly",
		Default = false,
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({ShowEnemyOnly = Value})
		end
	})

	Section:Toggle({
		Name = "Use Team Colors",
		Flag = "UseTeamColors",
		Default = false,
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({UseTeamColors = Value})
		end
	})

	Section:Toggle({
		Name = "Use Actual Team Colors",
		Flag = "UseActualTeamColors",
		Default = true,
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({UseActualTeamColors = Value})
		end
	})

	Section:Label("Box Color"):Colorpicker({
		Name = "Box Color",
		Flag = "BoxColor",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({BoxColor = Value})
		end
	})

	Section:Label("Self Box Color"):Colorpicker({
		Name = "Self Box Color",
		Flag = "SelfBoxColor",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({SelfBoxColor = Value})
		end
	})

	-- ⭐ THÊM MÀU NPC BOX
	Section:Label("NPC Box Color"):Colorpicker({
		Name = "NPC Box Color",
		Flag = "NPCBoxColor",
		Default = Color3.fromRGB(255, 100, 0),
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({NPCBoxColor = Value})
		end
	})

	Section:Label("Enemy Color"):Colorpicker({
		Name = "Enemy Color",
		Flag = "EnemyColor",
		Default = Color3.fromRGB(255, 0, 0),
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({EnemyBoxColor = Value})
		end
	})

	Section:Label("Allied Color"):Colorpicker({
		Name = "Allied Color",
		Flag = "AlliedColor",
		Default = Color3.fromRGB(0, 255, 0),
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({AlliedBoxColor = Value})
		end
	})

	Section:Label("No Team Color"):Colorpicker({
		Name = "No Team Color",
		Flag = "NoTeamColor",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({NoTeamColor = Value})
		end
	})

	Section:Toggle({
		Name = "Show Gradient",
		Flag = "ShowGradient",
		Default = false,
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({ShowGradient = Value})
		end
	})

	Section:Toggle({
		Name = "Enable Gradient Animation",
		Flag = "GradientAnimation",
		Default = false,
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({EnableGradientAnimation = Value})
		end
	})

	Section:Slider({
		Name = "Gradient Rotation",
		Flag = "GradientRotation",
		Min = 0,
		Max = 360,
		Default = 90,
		Decimals = 1,
		Suffix = "°",
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({GradientRotation = Value})
		end
	})

	Section:Slider({
		Name = "Gradient Animation Speed",
		Flag = "GradientSpeed",
		Min = 0.1,
		Max = 5,
		Default = 1,
		Decimals = 0.1,
		Suffix = "x",
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({GradientAnimationSpeed = Value})
		end
	})

	Section:Slider({
		Name = "Gradient Transparency",
		Flag = "GradientTransparency",
		Min = 0,
		Max = 1,
		Default = 0.7,
		Decimals = 0.01,
		Suffix = "",
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({GradientTransparency = Value})
		end
	})

	Section:Label("Gradient Color 1"):Colorpicker({
		Name = "Gradient Color 1",
		Flag = "GradientColor1",
		Default = Color3.fromRGB(255, 86, 0),
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({GradientColor1 = Value})
		end
	})

	Section:Label("Gradient Color 2"):Colorpicker({
		Name = "Gradient Color 2",
		Flag = "GradientColor2",
		Default = Color3.fromRGB(255, 0, 128),
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({GradientColor2 = Value})
		end
	})

	-- ⭐ THÊM SECTION NPC
	local NPCSection = EspPage:Section({
		Name = "NPC Settings",
		Description = "Configure NPC detection",
		Icon = "12053927543",
		Side = 1
	})

	NPCSection:Toggle({
		Name = "Aggressive NPC Detection",
		Flag = "AggressiveNPCDetection",
		Default = true,
		Callback = function(Value)
			BoxESPAPI:UpdateConfig({AggressiveNPCDetection = Value})
		end
	})

	NPCSection:Label("Aggressive mode sẽ detect tất cả model có humanoid làm NPC")
end
