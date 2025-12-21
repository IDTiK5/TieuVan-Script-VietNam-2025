return function(chamsTab, ChamsAPI)
	chamsTab:Toggle({
		Name = "Bật Chams",
		Flag = "Chams_BatChams",
		Default = false,
		Callback = function(value)
			ChamsAPI:Toggle(value)
		end
	})

	chamsTab:Dropdown({
		Name = "Loại Highlight",
		Flag = "Chams_LoaiHighlight",
		Items = {"Toàn Bộ", "Từng Bộ Phận"},
		Default = "Toàn Bộ",
		Callback = function(value)
			local mode = value == "Từng Bộ Phận"
			ChamsAPI:UpdateConfig({
				highlightSpecificParts = mode
			})
		end
	})

	chamsTab:Dropdown({
		Name = "Hiệu Ứng",
		Flag = "Chams_HieuUng",
		Items = {"Bình Thường", "Cầu Vồng", "Đập", "Chuyển Màu", "Nhìn Thấy", "Máu"},
		Default = "Bình Thường",
		Callback = function(value)
			local config = {
				rainbowEnabled = value == "Cầu Vồng",
				pulseEnabled = value == "Đập",
				gradientEnabled = value == "Chuyển Màu",
				useVisibilityColors = value == "Nhìn Thấy",
				healthColorEnabled = value == "Máu"
			}
			ChamsAPI:UpdateConfig(config)
		end
	})

	chamsTab:Dropdown({
		Name = "Chế Độ Sâu",
		Flag = "Chams_CheDoSau",
		Items = {"Luôn Trên Cùng", "Bị Che Khuất"},
		Default = "Luôn Trên Cùng",
		Callback = function(value)
			local depthMode = value == "Bị Che Khuất" and "Occluded" or "AlwaysOnTop"
			ChamsAPI:UpdateConfig({
				depthMode = depthMode
			})
		end
	})

	chamsTab:ColorPicker({
		Name = "Màu Nền",
		Flag = "Chams_MauNen",
		Color = Color3.fromRGB(0, 255, 140),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				fillColor = color,
				visibleFillColor = color
			})
		end
	})

	chamsTab:ColorPicker({
		Name = "Màu Viền",
		Flag = "Chams_MauVien",
		Color = Color3.fromRGB(0, 255, 140),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				outlineColor = color,
				visibleOutlineColor = color
			})
		end
	})

	chamsTab:ColorPicker({
		Name = "Màu Ẩn Núp",
		Flag = "Chams_MauAnNup",
		Color = Color3.fromRGB(255, 0, 0),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				hiddenFillColor = color,
				hiddenOutlineColor = color
			})
		end
	})

	chamsTab:ColorPicker({
		Name = "Màu Đồng Đội",
		Flag = "Chams_MauDongDoi",
		Color = Color3.fromRGB(0, 150, 255),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				teammateFillColor = color,
				teammateOutlineColor = color
			})
		end
	})

	chamsTab:ColorPicker({
		Name = "Gradient Màu 1",
		Flag = "Chams_GradientMau1",
		Color = Color3.fromRGB(255, 0, 0),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				gradientColor1 = color
			})
		end
	})

	chamsTab:ColorPicker({
		Name = "Gradient Màu 2",
		Flag = "Chams_GradientMau2",
		Color = Color3.fromRGB(0, 0, 255),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				gradientColor2 = color
			})
		end
	})

	chamsTab:ColorPicker({
		Name = "Máu Đầy Đủ",
		Flag = "Chams_MauMaxDay",
		Color = Color3.fromRGB(0, 255, 0),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				healthFullColor = color
			})
		end
	})

	chamsTab:ColorPicker({
		Name = "Máu Thấp",
		Flag = "Chams_MauThap",
		Color = Color3.fromRGB(255, 0, 0),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				healthLowColor = color
			})
		end
	})

	chamsTab:Slider({
		Name = "Khoảng Cách Tối Đa",
		Flag = "Chams_KhoangCach",
		Min = 0,
		Max = 50000,
		Default = 10000,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				maxDistance = value
			})
		end
	})

	chamsTab:Slider({
		Name = "Độ Mờ Nền",
		Flag = "Chams_DoMoNen",
		Min = 0,
		Max = 1,
		Default = 0.5,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				fillTransparency = value
			})
		end
	})

	chamsTab:Slider({
		Name = "Độ Mờ Viền",
		Flag = "Chams_DoMoVien",
		Min = 0,
		Max = 1,
		Default = 0,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				outlineTransparency = value
			})
		end
	})

	chamsTab:Slider({
		Name = "Tốc Độ Cập Nhật",
		Flag = "Chams_TocDoCap",
		Min = 1,
		Max = 20,
		Default = 5,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				batchSize = value
			})
		end
	})

	chamsTab:Slider({
		Name = "Tốc Độ Cầu Vồng",
		Flag = "Chams_TocDoCauVong",
		Min = 0.5,
		Max = 5,
		Default = 1,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				rainbowSpeed = value
			})
		end
	})

	chamsTab:Slider({
		Name = "Tốc Độ Đập",
		Flag = "Chams_TocDoDap",
		Min = 0.5,
		Max = 5,
		Default = 2,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				pulseSpeed = value
			})
		end
	})

	chamsTab:Slider({
		Name = "Tốc Độ Chuyển Màu",
		Flag = "Chams_TocDoChuyenMau",
		Min = 0.5,
		Max = 5,
		Default = 1,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				gradientSpeed = value
			})
		end
	})

	chamsTab:Slider({
		Name = "Bắt Đầu Mờ Dần",
		Flag = "Chams_BatDauMo",
		Min = 0,
		Max = 5000,
		Default = 500,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				fadeStartDistance = value
			})
		end
	})

	chamsTab:Slider({
		Name = "Kết Thúc Mờ Dần",
		Flag = "Chams_KetThucMo",
		Min = 0,
		Max = 5000,
		Default = 2000,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				fadeEndDistance = value
			})
		end
	})

	chamsTab:Slider({
		Name = "Cường Độ Sáng",
		Flag = "Chams_CuongDoGlow",
		Min = 0.5,
		Max = 3,
		Default = 1.5,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				glowIntensityMultiplier = value
			})
		end
	})

	chamsTab:Toggle({
		Name = "Cầu Vồng",
		Flag = "Chams_CauVong",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				rainbowEnabled = value
			})
		end
	})

	chamsTab:Toggle({
		Name = "Đập",
		Flag = "Chams_Dap",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				pulseEnabled = value
			})
		end
	})

	chamsTab:Toggle({
		Name = "Chuyển Màu",
		Flag = "Chams_ChuyenMau",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				gradientEnabled = value
			})
		end
	})

	chamsTab:Toggle({
		Name = "Theo Nhìn Thấy",
		Flag = "Chams_NhinThay",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				useVisibilityColors = value
			})
		end
	})

	chamsTab:Toggle({
		Name = "Màu Theo Máu",
		Flag = "Chams_MauTheoMau",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				healthColorEnabled = value
			})
		end
	})

	chamsTab:Toggle({
		Name = "Mờ Dần",
		Flag = "Chams_MoDan",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				distanceFadeEnabled = value
			})
		end
	})

	chamsTab:Toggle({
		Name = "Chỉ Viền",
		Flag = "Chams_ChiVien",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				outlineOnly = value
			})
		end
	})

	chamsTab:Toggle({
		Name = "Lọc Đồng Đội",
		Flag = "Chams_LocDongDoi",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				useTeamFilter = value
			})
		end
	})

	chamsTab:Toggle({
		Name = "Hiển Đồng Đội",
		Flag = "Chams_HienDongDoi",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				showTeammates = value
			})
		end
	})

	chamsTab:Toggle({
		Name = "Raycast",
		Flag = "Chams_Raycast",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				useRaycasting = value
			})
		end
	})

	chamsTab:Toggle({
		Name = "Mờ Khi Bị Che",
		Flag = "Chams_MoKhiChe",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				fadeWhenBlocked = value
			})
		end
	})

	chamsTab:Toggle({
		Name = "Sáng",
		Flag = "Chams_Glow",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				visibilityGlowEnabled = value
			})
		end
	})

	chamsTab:Toggle({
		Name = "Tự Phục Hồi Lỗi",
		Flag = "Chams_PhucHoi",
		Default = true,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				enableErrorRecovery = value
			})
		end
	})

	chamsTab:Toggle({
		Name = "Chế Độ Debug",
		Flag = "Chams_Debug",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				debugMode = value
			})
		end
	})

	chamsTab:Button({
		Name = "Làm Mới",
		Callback = function()
			ChamsAPI:ForceUpdateAll()
		end
	})

	chamsTab:Button({
		Name = "Phục Hồi Lỗi",
		Callback = function()
			ChamsAPI:ForceRecovery()
		end
	})

	chamsTab:Button({
		Name = "Đặt Lại Lỗi",
		Callback = function()
			ChamsAPI:ResetErrorTracking()
		end
	})
end
