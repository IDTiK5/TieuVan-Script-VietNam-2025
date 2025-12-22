return function(boxTab, HealthAPI)
	boxTab:Toggle({
		Name = "Bật Health Bar",
		Flag = "HealthBar_Enabled",
		Default = false,
		Callback = function(value)
			HealthBar:Toggle(value)
		end
	})

	boxTab:Dropdown({
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

	boxTab:Dropdown({
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

	boxTab:ColorPicker({
		Name = "Màu máu cao",
		Flag = "HealthHigh",
		Color = Color3.fromRGB(0, 255, 0),
		Callback = function(color)
			HealthBar:UpdateConfig({barColorHigh = color})
		end
	})

	boxTab:ColorPicker({
		Name = "Màu máu trung bình",
		Flag = "HealthMid",
		Color = Color3.fromRGB(255, 255, 0),
		Callback = function(color)
			HealthBar:UpdateConfig({barColorMid = color})
		end
	})

	boxTab:ColorPicker({
		Name = "Màu máu thấp",
		Flag = "HealthLow",
		Color = Color3.fromRGB(255, 0, 0),
		Callback = function(color)
			HealthBar:UpdateConfig({barColorLow = color})
		end
	})

	boxTab:ColorPicker({
		Name = "Màu static",
		Flag = "ColorStatic",
		Color = Color3.fromRGB(0, 255, 0),
		Callback = function(color)
			HealthBar:UpdateConfig({barColorStatic = color})
		end
	})

	boxTab:ColorPicker({
		Name = "Màu nền",
		Flag = "BackgroundColor",
		Color = Color3.fromRGB(40, 40, 40),
		Callback = function(color)
			HealthBar:UpdateConfig({backgroundColor = color})
		end
	})

	boxTab:ColorPicker({
		Name = "Màu viền",
		Flag = "OutlineColor",
		Color = Color3.fromRGB(0, 0, 0),
		Callback = function(color)
			HealthBar:UpdateConfig({outlineColor = color})
		end
	})

	boxTab:Slider({
		Name = "Chiều rộng (Ngang)",
		Flag = "BarWidth",
		Min = 20,
		Max = 200,
		Default = 60,
		Callback = function(value)
			HealthBar:UpdateConfig({barWidth = value})
		end
	})

	boxTab:Slider({
		Name = "Chiều cao (Ngang)",
		Flag = "BarHeight",
		Min = 1,
		Max = 20,
		Default = 4,
		Callback = function(value)
			HealthBar:UpdateConfig({barHeight = value})
		end
	})

	boxTab:Slider({
		Name = "Offset Y (Ngang)",
		Flag = "BarOffsetY",
		Min = -50,
		Max = 50,
		Default = -5,
		Callback = function(value)
			HealthBar:UpdateConfig({barOffsetY = value})
		end
	})

	boxTab:Slider({
		Name = "Chiều rộng (Dọc)",
		Flag = "VerticalWidth",
		Min = 1,
		Max = 20,
		Default = 4,
		Callback = function(value)
			HealthBar:UpdateConfig({verticalWidth = value})
		end
	})

	boxTab:Slider({
		Name = "Chiều cao (Dọc)",
		Flag = "VerticalHeight",
		Min = 20,
		Max = 200,
		Default = 40,
		Callback = function(value)
			HealthBar:UpdateConfig({verticalHeight = value})
		end
	})

	boxTab:Slider({
		Name = "Offset X (Dọc)",
		Flag = "VerticalOffsetX",
		Min = -50,
		Max = 50,
		Default = -35,
		Callback = function(value)
			HealthBar:UpdateConfig({verticalOffsetX = value})
		end
	})

	boxTab:Slider({
		Name = "Độ dày viền",
		Flag = "OutlineSize",
		Min = 0.5,
		Max = 5,
		Default = 1,
		Callback = function(value)
			HealthBar:UpdateConfig({outlineSize = value})
		end
	})

	boxTab:Slider({
		Name = "Tốc độ lerp",
		Flag = "LerpSpeed",
		Min = 0.01,
		Max = 0.5,
		Default = 0.15,
		Callback = function(value)
			HealthBar:UpdateConfig({lerpSpeed = value})
		end
	})

	boxTab:Toggle({
		Name = "Fade In/Out",
		Flag = "FadeInOut",
		Default = false,
		Callback = function(value)
			HealthBar:UpdateConfig({fadeInOut = value})
		end
	})

	boxTab:Slider({
		Name = "Tốc độ fade",
		Flag = "FadeSpeed",
		Min = 0.01,
		Max = 0.5,
		Default = 0.1,
		Callback = function(value)
			HealthBar:UpdateConfig({fadeSpeed = value})
		end
	})

	boxTab:Toggle({
		Name = "Hiển thị text máu",
		Flag = "ShowHealthText",
		Default = false,
		Callback = function(value)
			HealthBar:UpdateConfig({showHealthText = value})
		end
	})

	boxTab:Dropdown({
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

	boxTab:Dropdown({
		Name = "Vị trí text",
		Flag = "TextPosition",
		Items = {"Trên", "Dưới", "Trái", "Phải", "Giữa"},
		Default = "Trên",
		Callback = function(value)
			local positions = {["Trên"] = "top", ["Dưới"] = "bottom", ["Trái"] = "left", ["Phải"] = "right", ["Giữa"] = "center"}
			HealthBar:UpdateConfig({textPosition = positions[value]})
		end
	})

	boxTab:Slider({
		Name = "Kích thước text",
		Flag = "TextSize",
		Min = 8,
		Max = 24,
		Default = 13,
		Callback = function(value)
			HealthBar:UpdateConfig({textSize = value})
		end
	})

	boxTab:ColorPicker({
		Name = "Màu text",
		Flag = "TextColor",
		Color = Color3.fromRGB(255, 255, 255),
		Callback = function(color)
			HealthBar:UpdateConfig({textColor = color})
		end
	})

	boxTab:Toggle({
		Name = "Outline text",
		Flag = "TextOutline",
		Default = true,
		Callback = function(value)
			HealthBar:UpdateConfig({textOutline = value})
		end
	})

	boxTab:ColorPicker({
		Name = "Màu outline text",
		Flag = "TextOutlineColor",
		Color = Color3.fromRGB(0, 0, 0),
		Callback = function(color)
			HealthBar:UpdateConfig({textOutlineColor = color})
		end
	})

	boxTab:Slider({
		Name = "Offset X text",
		Flag = "TextOffsetX",
		Min = -50,
		Max = 50,
		Default = 0,
		Callback = function(value)
			HealthBar:UpdateConfig({textOffsetX = value})
		end
	})

	boxTab:Slider({
		Name = "Offset Y text",
		Flag = "TextOffsetY",
		Min = -50,
		Max = 50,
		Default = -15,
		Callback = function(value)
			HealthBar:UpdateConfig({textOffsetY = value})
		end
	})

	boxTab:Toggle({
		Name = "Lọc đội",
		Flag = "TeamFilter",
		Default = false,
		Callback = function(value)
			HealthBar:UpdateConfig({teamFilter = value})
		end
	})

	boxTab:Dropdown({
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

	boxTab:Slider({
		Name = "Khoảng cách tối đa",
		Flag = "MaxDistance",
		Min = 100,
		Max = 10000,
		Default = 5000,
		Callback = function(value)
			HealthBar:UpdateConfig({maxDistance = value})
		end
	})

	boxTab:Toggle({
		Name = "Khôi phục lỗi tự động",
		Flag = "ErrorRecovery",
		Default = true,
		Callback = function(value)
			HealthBar:UpdateConfig({enableErrorRecovery = value})
		end
	})

	boxTab:Toggle({
		Name = "Chế độ gỡ lỗi",
		Flag = "DebugMode",
		Default = false,
		Callback = function(value)
			HealthBar:UpdateConfig({debugMode = value})
		end
	})

	boxTab:Button({
		Name = "Làm mới Health Bar",
		Callback = function()
			HealthBar:Refresh()
		end
	})

	boxTab:Button({
		Name = "Reset lỗi",
		Callback = function()
			HealthBar:ResetErrors()
		end
	})
end
