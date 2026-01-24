return function(PlayerPage, PlayerAPI)
	local CharacterSection = PlayerPage:Section({
		Name = "Character",
		Description = "Feature",
		Icon = "98376828270066",
		Side = 1
	})

	--=============================================================================
	-- FLY SECTION
	--=============================================================================

	CharacterSection:Toggle({
		Name = "Fly",
		Flag = "FlyEnable",
		Default = false,
		Callback = function(Value)
			if Value then
				PlayerAPI:EnableFly()
			else
				PlayerAPI:DisableFly()
			end
		end
	})

	CharacterSection:Slider({
		Name = "Fly Speed",
		Flag = "FlySpeed",
		Min = 1,
		Max = 100,
		Default = 5,
		Decimals = 1,
		Suffix = "m/s",
		Callback = function(Value)
			PlayerAPI:SetFlySpeed(Value)
		end
	})

	CharacterSection:Slider({
		Name = "Max Fly Speed",
		Flag = "FlyMaxSpeed",
		Min = 5,
		Max = 500,
		Default = 500,
		Decimals = 1,
		Suffix = "m/s",
		Callback = function(Value)
			PlayerAPI:SetMaxFlySpeed(Value)
		end
	})

	CharacterSection:Slider({
		Name = "Acceleration",
		Flag = "FlyAcceleration",
		Min = 1,
		Max = 50,
		Default = 10,
		Decimals = 1,
		Suffix = "x",
		Callback = function(Value)
			PlayerAPI:SetAcceleration(Value)
		end
	})

	--=============================================================================
	-- SPEED SECTION
	--=============================================================================

	CharacterSection:Toggle({
		Name = "Speed",
		Flag = "SpeedEnable",
		Default = false,
		Callback = function(Value)
			if Value then
				PlayerAPI:EnableSpeed()
			else
				PlayerAPI:DisableSpeed()
			end
		end
	})

	CharacterSection:Slider({
		Name = "Speed Value",
		Flag = "SpeedValue",
		Min = 10,
		Max = 50000,
		Default = 50,
		Decimals = 1,
		Suffix = "m/s",
		Callback = function(Value)
			PlayerAPI:SetSpeedValue(Value)
		end
	})

	CharacterSection:Textbox({
		Flag = "SpeedTextbox",
		Default = "50",
		Numeric = true,
		Placeholder = "Nhập Speed Value...",
		Finished = true,
		Callback = function(Value)
			local numValue = tonumber(Value)
			if numValue then
				numValue = math.clamp(numValue, 1, 100000)
				PlayerAPI:SetSpeedValue(numValue)
			end
		end
	})

	--=============================================================================
	-- JUMP SECTION
	--=============================================================================

	CharacterSection:Toggle({
		Name = "High Jump",
		Flag = "JumpEnable",
		Default = false,
		Callback = function(Value)
			if Value then
				PlayerAPI:EnableJump()
			else
				PlayerAPI:DisableJump()
			end
		end
	})

	CharacterSection:Slider({
		Name = "Jump Power",
		Flag = "JumpPower",
		Min = 5,
		Max = 10000,
		Default = 50,
		Decimals = 1,
		Suffix = "studs",
		Callback = function(Value)
			PlayerAPI:SetJumpPower(Value)
		end
	})

	CharacterSection:Textbox({
		Flag = "JumpTextbox",
		Default = "50",
		Numeric = true,
		Placeholder = "Nhập Jump Power...",
		Finished = true,
		Callback = function(Value)
			local numValue = tonumber(Value)
			if numValue then
				numValue = math.clamp(numValue, 1, 100000)
				PlayerAPI:SetJumpPower(numValue)
			end
		end
	})

	CharacterSection:Toggle({
		Name = "Infinite Jump",
		Flag = "InfiniteJumpEnable",
		Default = false,
		Callback = function(Value)
			if Value then
				PlayerAPI:EnableInfiniteJump()
			else
				PlayerAPI:DisableInfiniteJump()
			end
		end
	})

	CharacterSection:Toggle({
		Name = "Auto Jump",
		Flag = "AutoJumpEnable",
		Default = false,
		Callback = function(Value)
			if Value then
				PlayerAPI:EnableAutoJump()
			else
				PlayerAPI:DisableAutoJump()
			end
		end
	})

	--=============================================================================
	-- NOCLIP SECTION
	--=============================================================================

	CharacterSection:Toggle({
		Name = "Noclip",
		Flag = "NoclipEnable",
		Default = false,
		Callback = function(Value)
			if Value then
				PlayerAPI:EnableNoclip()
			else
				PlayerAPI:DisableNoclip()
			end
		end
	})

	--=============================================================================
	-- UTILITY SECTION
	--=============================================================================

	CharacterSection:Button({
		Name = "Reset Character",
		Callback = function()
			PlayerAPI:ResetCharacter()
		end
	})

	CharacterSection:Button({
		Name = "Disable All",
		Callback = function()
			PlayerAPI:DisableAll()
		end
	})
end
