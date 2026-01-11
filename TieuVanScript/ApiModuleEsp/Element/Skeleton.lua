return function(EspPage, SkeletonESPAPI)
	local SkeletonSection = EspPage:Section({
		Name = "Skeleton ESP",
		Description = "Draw skeleton on players",
		Icon = "10709781605",
		Side = 2
	})

	SkeletonSection:Toggle({
		Name = "Enable Skeleton",
		Flag = "SkeletonToggle",
		Default = false,
		Callback = function(Value)
			SkeletonESPAPI:UpdateConfig({Enabled = Value})
			SkeletonESPAPI:Toggle(Value)
		end
	})

	SkeletonSection:Toggle({
		Name = "Team Check",
		Flag = "SkeletonTeamCheck",
		Default = false,
		Callback = function(Value)
			SkeletonESPAPI:UpdateConfig({EnableTeamCheck = Value})
		end
	})

	SkeletonSection:Toggle({
		Name = "Enemy Only",
		Flag = "SkeletonEnemyOnly",
		Default = false,
		Callback = function(Value)
			SkeletonESPAPI:UpdateConfig({ShowEnemyOnly = Value})
		end
	})

	SkeletonSection:Toggle({
		Name = "Allied Only",
		Flag = "SkeletonAlliedOnly",
		Default = false,
		Callback = function(Value)
			SkeletonESPAPI:UpdateConfig({ShowAlliedOnly = Value})
		end
	})

	SkeletonSection:Slider({
		Name = "Transparency",
		Flag = "SkeletonTransparency",
		Min = 0,
		Max = 1,
		Default = 1,
		Decimals = 0.1,
		Suffix = "",
		Callback = function(Value)
			SkeletonESPAPI:UpdateConfig({SkeletonTransparency = Value})
		end
	})

	SkeletonSection:Toggle({
		Name = "Use Team Colors",
		Flag = "SkeletonUseTeamColors",
		Default = false,
		Callback = function(Value)
			SkeletonESPAPI:UpdateConfig({UseTeamColors = Value})
		end
	})

	SkeletonSection:Toggle({
		Name = "Use Actual Team Colors",
		Flag = "SkeletonUseActualTeamColors",
		Default = true,
		Callback = function(Value)
			SkeletonESPAPI:UpdateConfig({UseActualTeamColors = Value})
		end
	})

	SkeletonSection:Label("Skeleton Color"):Colorpicker({
		Name = "Color",
		Flag = "SkeletonColor",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			SkeletonESPAPI:UpdateConfig({SkeletonColor = Value})
		end
	})

	SkeletonSection:Label("Enemy Color"):Colorpicker({
		Name = "Enemy Color",
		Flag = "SkeletonEnemyColor",
		Default = Color3.fromRGB(255, 0, 0),
		Callback = function(Value)
			SkeletonESPAPI:UpdateConfig({EnemySkeletonColor = Value})
		end
	})

	SkeletonSection:Label("Allied Color"):Colorpicker({
		Name = "Allied Color",
		Flag = "SkeletonAlliedColor",
		Default = Color3.fromRGB(0, 255, 0),
		Callback = function(Value)
			SkeletonESPAPI:UpdateConfig({AlliedSkeletonColor = Value})
		end
	})

	SkeletonSection:Label("No Team Color"):Colorpicker({
		Name = "No Team Color",
		Flag = "SkeletonNoTeamColor",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			SkeletonESPAPI:UpdateConfig({NoTeamColor = Value})
		end
	})
end
