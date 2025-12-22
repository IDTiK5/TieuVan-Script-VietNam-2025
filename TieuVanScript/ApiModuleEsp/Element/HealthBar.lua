return function(healthTab, HealthAPI)
	healthTab:Toggle({
		Name = "Bật Health Bar",
		Flag = "HealthBar_Enabled",
		Default = true,
		Callback = function(value)
			HealthBar:Toggle(value)
		end
	})

	healthTab:Dropdown({
		Name = "Kiểu Health Bar",
		Flag = "BarStyle",
		Items = {"Ngang", "Dọc"},
		Default = "Ngang",
		Callback = function(value)
			if value == "Ngang" then
				HealthBar:UpdateConfig({barStyle = "horizontal"})
			else
				HealthBar:UpdateConfig({barStyle = "vertical"})
			end
		end
	})

	healthTab:Dropdown({
		Name = "Chế độ màu",
		Flag = "ColorMode",
		Items = {"Tĩnh", "Gradient", "Cầu vồng"},
		Default = "Gradient",
		Callback = function(value)
			if value == "Tĩnh" then
				HealthBar:UpdateConfig({barColorMode = "static"})
			elseif value == "Gradient" then
				HealthBar:UpdateConfig({barColorMode = "gradient"})
			else
				HealthBar:UpdateConfig({barColorMode = "rainbow"})
			end
		end
	})

	healthTab:ColorPicker({
		Name = "Màu máu cao",
		Flag = "HealthHigh",
		Color = Color3.fromRGB(0, 255, 0),
		Callback = function(color)
			HealthBar:UpdateConfig({barColorHigh = color})
		end
	})

	healthTab:ColorPicker({
		Name = "Màu máu trung bình",
		Flag = "HealthMid",
		Color = Color3.fromRGB(255, 255, 0),
		Callback = function(color)
			HealthBar:UpdateConfig({barColorMid = color})
		end
	})

	healthTab:ColorPicker({
		Name = "Màu máu thấp",
		Flag = "HealthLow",
		Color = Color3.fromRGB(255, 0, 0),
		Callback = function(color)
			HealthBar:UpdateConfig({barColorLow = color})
		end
	})

	healthTab:ColorPicker({
		Name = "Màu static",
		Flag = "ColorStatic",
		Color = Color3.fromRGB(0, 255, 0),
		Callback = function(color)
			HealthBar:UpdateConfig({barColorStatic = color})
		end
	})

	healthTab:ColorPicker({
		Name = "Màu nền",
		Flag = "BackgroundColor",
		Color = Color3.fromRGB(40, 40, 40),
		Callback = function(color)
			HealthBar:UpdateConfig({backgroundColor = color})
		end
	})

	healthTab:ColorPicker({
		Name = "Màu viền",
		Flag = "OutlineColor",
		Color = Color3.fromRGB(0, 0, 0),
		Callback = function(color)
			HealthBar:UpdateConfig({outlineColor = color})
		end
	})

	healthTab:Slider({
		Name = "Chiều rộng (Ngang)",
		Flag = "BarWidth",
		Min = 20,
		Max = 200,
		Default = 60,
		Callback = function(value)
			HealthBar:UpdateConfig({barWidth = value})
		end
	})

	healthTab:Slider({
		Name = "Chiều cao (Ngang)",
		Flag = "BarHeight",
		Min = 1,
		Max = 20,
		Default = 4,
		Callback = function(value)
			HealthBar:UpdateConfig({barHeight = value})
		end
	})

	healthTab:Slider({
		Name = "Offset Y (Ngang)",
		Flag = "BarOffsetY",
		Min = -50,
		Max = 50,
		Default = -5,
		Callback = function(value)
			HealthBar:UpdateConfig({barOffsetY = value})
		end
	})

	healthTab:Slider({
		Name = "Chiều rộng (Dọc)",
		Flag = "VerticalWidth",
		Min = 1,
		Max = 20,
		Default = 4,
		Callback = function(value)
			HealthBar:UpdateConfig({verticalWidth = value})
		end
	})

	healthTab:Slider({
		Name = "Chiều cao (Dọc)",
		Flag = "VerticalHeight",
		Min = 20,
		Max = 200,
		Default = 40,
		Callback = function(value)
			HealthBar:UpdateConfig({verticalHeight = value})
		end
	})

	healthTab:Slider({
		Name = "Offset X (Dọc)",
		Flag = "VerticalOffsetX",
		Min = -50,
		Max = 50,
		Default = -35,
		Callback = function(value)
			HealthBar:UpdateConfig({verticalOffsetX = value})
		end
	})

	healthTab:Slider({
		Name = "Độ dày viền",
		Flag = "OutlineSize",
		Min = 0.5,
		Max = 5,
		Default = 1,
		Callback = function(value)
			HealthBar:UpdateConfig({outlineSize = value})
		end
	})

	healthTab:Slider({
		Name = "Tốc độ lerp",
		Flag = "LerpSpeed",
		Min = 0.01,
		Max = 0.5,
		Default = 0.15,
		Callback = function(value)
			HealthBar:UpdateConfig({lerpSpeed = value})
		end
	})

	healthTab:Toggle({
		Name = "Fade In/Out",
		Flag = "FadeInOut",
		Default = false,
		Callback = function(value)
			HealthBar:UpdateConfig({fadeInOut = value})
		end
	})

	healthTab:Slider({
		Name = "Tốc độ fade",
		Flag = "FadeSpeed",
		Min = 0.01,
		Max = 0.5,
		Default = 0.1,
		Callback = function(value)
			HealthBar:UpdateConfig({fadeSpeed = value})
		end
	})

	healthTab:Toggle({
		Name = "Hiển thị text máu",
		Flag = "ShowHealthText",
		Default = false,
		Callback = function(value)
			HealthBar:UpdateConfig({showHealthText = value})
		end
	})

	healthTab:Dropdown({
		Name = "Kiểu text máu",
		Flag = "TextMode",
		Items = {"Phần trăm", "Giá trị", "Cả hai"},
		Default = "Phần trăm",
		Callback = function(value)
			if value == "Phần trăm" then
				HealthBar:UpdateConfig({textMode = "percent"})
			elseif value == "Giá trị" then
				HealthBar:UpdateConfig({textMode = "value"})
			else
				HealthBar:UpdateConfig({textMode = "both"})
			end
		end
	})

	healthTab:Dropdown({
		Name = "Vị trí text",
		Flag = "TextPosition",
		Items = {"Trên", "Dưới", "Trái", "Phải", "Giữa"},
		Default = "Trên",
		Callback = function(value)
			local positions = {["Trên"] = "top", ["Dưới"] = "bottom", ["Trái"] = "left", ["Phải"] = "right", ["Giữa"] = "center"}
			HealthBar:UpdateConfig({textPosition = positions[value]})
		end
	})

	healthTab:Slider({
		Name = "Kích thước text",
		Flag = "TextSize",
		Min = 8,
		Max = 24,
		Default = 13,
		Callback = function(value)
			HealthBar:UpdateConfig({textSize = value})
		end
	})

	healthTab:ColorPicker({
		Name = "Màu text",
		Flag = "TextColor",
		Color = Color3.fromRGB(255, 255, 255),
		Callback = function(color)
			HealthBar:UpdateConfig({textColor = color})
		end
	})

	healthTab:Toggle({
		Name = "Outline text",
		Flag = "TextOutline",
		Default = true,
		Callback = function(value)
			HealthBar:UpdateConfig({textOutline = value})
		end
	})

	healthTab:ColorPicker({
		Name = "Màu outline text",
		Flag = "TextOutlineColor",
		Color = Color3.fromRGB(0, 0, 0),
		Callback = function(color)
			HealthBar:UpdateConfig({textOutlineColor = color})
		end
	})

	healthTab:Slider({
		Name = "Offset X text",
		Flag = "TextOffsetX",
		Min = -50,
		Max = 50,
		Default = 0,
		Callback = function(value)
			HealthBar:UpdateConfig({textOffsetX = value})
		end
	})

	healthTab:Slider({
		Name = "Offset Y text",
		Flag = "TextOffsetY",
		Min = -50,
		Max = 50,
		Default = -15,
		Callback = function(value)
			HealthBar:UpdateConfig({textOffsetY = value})
		end
	})

	healthTab:Toggle({
		Name = "Lọc đội",
		Flag = "TeamFilter",
		Default = false,
		Callback = function(value)
			HealthBar:UpdateConfig({teamFilter = value})
		end
	})

	healthTab:Dropdown({
		Name = "Chế độ lọc đội",
		Flag = "TeamFilterMode",
		Items = {"Standard", "Attribute"},
		Default = "Standard",
		Callback = function(value)
			if value == "Standard" then
				HealthBar:UpdateConfig({teamFilterMode = "standard"})
			else
				HealthBar:UpdateConfig({teamFilterMode = "attribute"})
			end
		end
	})

	healthTab:Slider({
		Name = "Khoảng cách tối đa",
		Flag = "MaxDistance",
		Min = 100,
		Max = 10000,
		Default = 5000,
		Callback = function(value)
			HealthBar:UpdateConfig({maxDistance = value})
		end
	})

	healthTab:Toggle({
		Name = "Khôi phục lỗi tự động",
		Flag = "ErrorRecovery",
		Default = true,
		Callback = function(value)
			HealthBar:UpdateConfig({enableErrorRecovery = value})
		end
	})

	healthTab:Toggle({
		Name = "Chế độ gỡ lỗi",
		Flag = "DebugMode",
		Default = false,
		Callback = function(value)
			HealthBar:UpdateConfig({debugMode = value})
		end
	})

	healthTab:Button({
		Name = "Làm mới Health Bar",
		Callback = function()
			HealthBar:Refresh()
		end
	})

	healthTab:Button({
		Name = "Reset lỗi",
		Callback = function()
			HealthBar:ResetErrors()
		end
	})
end
