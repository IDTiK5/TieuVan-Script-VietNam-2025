return function(boxTab, BoxApi)
	boxTab:Toggle({
		Name = "Bật ESP",
		Flag = "ESP_Enabled",
		Default = false,
		Callback = function(value)
			ESP.config.enabled = value
		end
	})

	boxTab:Dropdown({
		Name = "Kiểu hộp",
		Flag = "BoxType",
		Items = {"Hộp 2D", "Hộp 3D", "Hộp góc"},
		Default = "Hộp 2D",
		Callback = function(value)
			if value == "Hộp 2D" then
				ESP.config.box3D = false
				ESP.config.cornerBox = false
			elseif value == "Hộp 3D" then
				ESP.config.box3D = true
				ESP.config.cornerBox = false
			elseif value == "Hộp góc" then
				ESP.config.box3D = false
				ESP.config.cornerBox = true
			end
			ESP:ForceResort()
		end
	})

	boxTab:ColorPicker({
		Name = "Màu hộp",
		Flag = "BoxColor",
		Color = Color3.fromRGB(255, 255, 255),
		Callback = function(color)
			ESP.config.boxColor = color
		end
	})

	boxTab:Slider({
		Name = "Khoảng cách tối đa",
		Flag = "MaxDistance",
		Min = 0,
		Max = 10000,
		Default = 10000,
		Callback = function(value)
			ESP.config.maxDistance = value
		end
	})

	boxTab:Toggle({
		Name = "Tô màu hộp",
		Flag = "BoxFilled",
		Default = false,
		Callback = function(value)
			ESP.config.boxFilled = value
		end
	})

	boxTab:Toggle({
		Name = "Viền hộp",
		Flag = "BoxOutline",
		Default = false,
		Callback = function(value)
			ESP.config.boxOutline = value
		end
	})

	boxTab:Toggle({
		Name = "Kiểm tra tường",
		Flag = "RaycastCheck",
		Default = false,
		Callback = function(value)
			ESP.config.raycastCheck = value
		end
	})

	boxTab:Toggle({
		Name = "Mờ khi bị chắn",
		Flag = "FadeBlocked",
		Default = false,
		Callback = function(value)
			ESP.config.fadeWhenBlocked = value
		end
	})

	boxTab:Toggle({
		Name = "Mờ theo khoảng cách",
		Flag = "DistanceFade",
		Default = false,
		Callback = function(value)
			ESP.config.distanceFade = value
		end
	})

	boxTab:Toggle({
		Name = "Lọc đội",
		Flag = "TeamFilter",
		Default = false,
		Callback = function(value)
			ESP.config.teamFilter = value
			ESP:Refresh()
		end
	})

	boxTab:Dropdown({
		Name = "Chế độ lọc đội",
		Flag = "TeamFilterMode",
		Items = {"Tiêu chuẩn", "Nâng cao"},
		Default = "Tiêu chuẩn",
		Callback = function(value)
			if value == "Tiêu chuẩn" then
				ESP.config.teamFilterMode = "standard"
			else
				ESP.config.teamFilterMode = "advanced"
			end
			ESP:Refresh()
		end
	})

	boxTab:Dropdown({
		Name = "Chế độ màu",
		Flag = "ColorMode",
		Items = {"Tĩnh", "Cầu vồng", "Máu", "Đội", "Khoảng cách"},
		Default = "Tĩnh",
		Callback = function(value)
			if value == "Tĩnh" then
				ESP.config.colorMode = "Static"
			elseif value == "Cầu vồng" then
				ESP.config.colorMode = "Rainbow"
			elseif value == "Máu" then
				ESP.config.colorMode = "Health"
			elseif value == "Đội" then
				ESP.config.colorMode = "Team"
			else
				ESP.config.colorMode = "Distance"
			end
		end
	})

	boxTab:Slider({
		Name = "Độ dày viền",
		Flag = "Thickness",
		Min = 0.5,
		Max = 5,
		Default = 1.5,
		Callback = function(value)
			ESP.config.thickness = value
		end
	})

	boxTab:Slider({
		Name = "Độ trong suốt",
		Flag = "Transparency",
		Min = 0,
		Max = 1,
		Default = 1,
		Callback = function(value)
			ESP.config.transparency = value
		end
	})

	boxTab:Slider({
		Name = "Tốc độ cập nhật",
		Flag = "UpdateRate",
		Min = 1,
		Max = 10,
		Default = 1,
		Callback = function(value)
			ESP.config.updateRate = value
		end
	})

	boxTab:ColorPicker({
		Name = "Màu viền",
		Flag = "OutlineColor",
		Color = Color3.fromRGB(255, 255, 255),
		Callback = function(color)
			ESP.config.outlineColor = color
		end
	})

	boxTab:Slider({
		Name = "Độ dày viền ngoài",
		Flag = "OutlineThickness",
		Min = 0.5,
		Max = 5,
		Default = 3,
		Callback = function(value)
			ESP.config.outlineThickness = value
		end
	})

	boxTab:Slider({
		Name = "Độ dài góc",
		Flag = "CornerLength",
		Min = 0.1,
		Max = 1,
		Default = 0.25,
		Callback = function(value)
			ESP.config.cornerLength = value
		end
	})

	boxTab:Slider({
		Name = "Độ mờ tô màu",
		Flag = "FillTransparency",
		Min = 0,
		Max = 1,
		Default = 0.8,
		Callback = function(value)
			ESP.config.fillTransparency = value
		end
	})

	boxTab:Toggle({
		Name = "Hộp động",
		Flag = "DynamicBox",
		Default = false,
		Callback = function(value)
			ESP.config.dynamicBox = value
		end
	})

	boxTab:Slider({
		Name = "Tốc độ cầu vồng",
		Flag = "RainbowSpeed",
		Min = 0.1,
		Max = 5,
		Default = 1,
		Callback = function(value)
			ESP.config.rainbowSpeed = value
		end
	})

	boxTab:Slider({
		Name = "Số người mỗi khung",
		Flag = "MaxPlayersPerFrame",
		Min = 1,
		Max = 50,
		Default = 10,
		Callback = function(value)
			ESP.config.maxPlayersPerFrame = value
		end
	})

	boxTab:Slider({
		Name = "Thời gian lưu raycast",
		Flag = "RaycastCacheDuration",
		Min = 0.05,
		Max = 1,
		Default = 0.1,
		Callback = function(value)
			ESP.config.raycastCacheDuration = value
		end
	})

	boxTab:Slider({
		Name = "Khoảng thời gian dọn dẹp",
		Flag = "PoolCleanupInterval",
		Min = 5,
		Max = 60,
		Default = 30,
		Callback = function(value)
			ESP.config.poolCleanupInterval = value
		end
	})

	boxTab:Toggle({
		Name = "Khôi phục lỗi tự động",
		Flag = "ErrorRecovery",
		Default = true,
		Callback = function(value)
			ESP.config.enableErrorRecovery = value
		end
	})

	boxTab:Toggle({
		Name = "Chế độ gỡ lỗi",
		Flag = "DebugMode",
		Default = false,
		Callback = function(value)
			ESP.config.debugMode = value
		end
	})

	boxTab:Button({
		Name = "Làm mới ESP",
		Callback = function()
			ESP:Refresh()
		end
	})

	boxTab:Button({
		Name = "Xóa bộ nhớ đệm",
		Callback = function()
			ESP.cache = {}
			ESP.validationData = {}
			ESP.validationTime = {}
		end
	})
end
