return function(EspPage, HealthBarESPAPI)
	local HealthBarSection = EspPage:Section({
		Name = "Health Bar ESP",
		Description = "Display health bars for players",
		Icon = "77774174241071",
		Side = 2
	})

	HealthBarSection:Toggle({
		Name = "Enable Health Bar",
		Flag = "HealthBarToggle",
		Default = false,
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({Enabled = Value})
			HealthBarESPAPI:Toggle(Value)
		end
	})

	HealthBarSection:Toggle({
		Name = "Team Check",
		Flag = "HealthTeamCheck",
		Default = false,
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({EnableTeamCheck = Value})
		end
	})

	HealthBarSection:Toggle({
		Name = "Enemy Only",
		Flag = "HealthEnemyOnly",
		Default = false,
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({ShowEnemyOnly = Value})
		end
	})

	HealthBarSection:Toggle({
		Name = "Show Self Health Bar",
		Flag = "ShowSelfHealthBar",
		Default = false,
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({ShowSelfHealthBar = Value})
		end
	})

	HealthBarSection:Dropdown({
		Name = "Position",
		Flag = "HealthBarSide",
		Default = "Left",
		Items = {"Left", "Right"},
		Multi = false,
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({Side = Value})
		end
	})

	HealthBarSection:Slider({
		Name = "Offset X",
		Flag = "OffsetX",
		Min = -50,
		Max = 100,
		Default = 0,
		Decimals = 0.1,
		Suffix = "px",
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({OffsetX = Value})
		end
	})

	HealthBarSection:Slider({
		Name = "Offset Y",
		Flag = "OffsetY",
		Min = -50,
		Max = 100,
		Default = 0,
		Decimals = 0.1,
		Suffix = "px",
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({OffsetY = Value})
		end
	})

	HealthBarSection:Slider({
		Name = "Gap Distance",
		Flag = "HealthBarGap",
		Min = 0,
		Max = 20,
		Default = 2,
		Decimals = 0.1,
		Suffix = "px",
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({HealthBarGap = Value})
		end
	})

	HealthBarSection:Slider({
		Name = "Bar Width",
		Flag = "HealthBarWidth",
		Min = 1,
		Max = 10,
		Default = 3,
		Decimals = 0.1,
		Suffix = "px",
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({HealthBarWidth = Value})
		end
	})

	HealthBarSection:Slider({
		Name = "Animation Speed",
		Flag = "AnimationSpeed",
		Min = 0.1,
		Max = 1,
		Default = 0.3,
		Decimals = 0.1,
		Suffix = "s",
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({AnimationSpeed = Value})
		end
	})

	HealthBarSection:Toggle({
		Name = "Use Team Colors",
		Flag = "UseTeamColors",
		Default = false,
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({UseTeamColors = Value})
		end
	})

	HealthBarSection:Toggle({
		Name = "Use Actual Team Colors",
		Flag = "UseActualTeamColors",
		Default = true,
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({UseActualTeamColors = Value})
		end
	})

	HealthBarSection:Toggle({
		Name = "Enable Flash Effect",
		Flag = "EnableFlashEffect",
		Default = true,
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({EnableFlashEffect = Value})
		end
	})

	HealthBarSection:Slider({
		Name = "Flash Duration",
		Flag = "FlashDuration",
		Min = 0.05,
		Max = 0.5,
		Default = 0.15,
		Decimals = 0.05,
		Suffix = "s",
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({FlashDuration = Value})
		end
	})

	HealthBarSection:Label("Enemy Color"):Colorpicker({
		Name = "Enemy Health Color",
		Flag = "EnemyHealthColor",
		Default = Color3.fromRGB(180, 0, 255),
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({EnemyHealthBarColor = Value})
		end
	})

	HealthBarSection:Label("Allied Color"):Colorpicker({
		Name = "Allied Health Color",
		Flag = "AlliedHealthColor",
		Default = Color3.fromRGB(0, 255, 0),
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({AlliedHealthBarColor = Value})
		end
	})

	HealthBarSection:Label("No Team Color"):Colorpicker({
		Name = "No Team Color",
		Flag = "NoTeamColor",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({NoTeamColor = Value})
		end
	})

	HealthBarSection:Label("Damage Flash Color"):Colorpicker({
		Name = "Damage Flash Color",
		Flag = "DamageFlashColor",
		Default = Color3.fromRGB(255, 0, 0),
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({DamageFlashColor = Value})
		end
	})

	HealthBarSection:Label("Heal Flash Color"):Colorpicker({
		Name = "Heal Flash Color",
		Flag = "HealFlashColor",
		Default = Color3.fromRGB(0, 255, 100),
		Callback = function(Value)
			HealthBarESPAPI:UpdateConfig({HealFlashColor = Value})
		end
	})
end
