return function(PlayerPage, Player2API)
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
				Player2API:EnableFly()
			else
				Player2API:DisableFly()
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
			Player2API:SetFlySpeed(Value)
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
			Player2API:SetMaxFlySpeed(Value)
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
			Player2API:SetAcceleration(Value)
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
				Player2API:EnableSpeed()
			else
				Player2API:DisableSpeed()
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
			Player2API:SetSpeedValue(Value)
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
				Player2API:SetSpeedValue(numValue)
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
				Player2API:EnableJump()
			else
				Player2API:DisableJump()
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
			Player2API:SetJumpPower(Value)
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
				Player2API:SetJumpPower(numValue)
			end
		end
	})

	CharacterSection:Toggle({
		Name = "Infinite Jump",
		Flag = "InfiniteJumpEnable",
		Default = false,
		Callback = function(Value)
			if Value then
				Player2API:EnableInfiniteJump()
			else
				Player2API:DisableInfiniteJump()
			end
		end
	})

	CharacterSection:Toggle({
		Name = "Auto Jump",
		Flag = "AutoJumpEnable",
		Default = false,
		Callback = function(Value)
			if Value then
				Player2API:EnableAutoJump()
			else
				Player2API:DisableAutoJump()
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
				Player2API:EnableNoclip()
			else
				Player2API:DisableNoclip()
			end
		end
	})

	--=============================================================================
	-- UTILITY SECTION
	--=============================================================================

	CharacterSection:Button({
		Name = "Reset Character",
		Callback = function()
			Player2API:ResetCharacter()
		end
	})

	CharacterSection:Button({
		Name = "Disable All",
		Callback = function()
			Player2API:DisableAll()
		end
	})
end
