return function(chamsTab, ChamsAPI)
	-- ═══════════════════════════════════════════════════════════════
	-- NHÓM 1: CÀI ĐẶT CHÍNH
	-- ═══════════════════════════════════════════════════════════════
	
	chamsTab:Label({
		Name = "⚡ CÀI ĐẶT CHÍNH"
	})

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

	chamsTab:Divider()

	-- ═══════════════════════════════════════════════════════════════
	-- NHÓM 2: HIỆU ỨNG
	-- ═══════════════════════════════════════════════════════════════
	
	chamsTab:Label({
		Name = "🎨 HIỆU ỨNG"
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
		Name = "Viền Động",
		Flag = "Chams_VienDong",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				dynamicOutlineWidth = value
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

	chamsTab:Divider()

	-- ═══════════════════════════════════════════════════════════════
	-- NHÓM 3: MÀU SẮC CƠ BẢN
	-- ═══════════════════════════════════════════════════════════════
	
	chamsTab:Label({
		Name = "🎨 MÀU SẮC CƠ BẢN"
	})

	chamsTab:ColorPicker({
		Name = "Màu Nền",
		Flag = "Chams_MauNen",
		Color = Color3.fromRGB(0, 255, 140),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				fillColor = color
			})
		end
	})

	chamsTab:ColorPicker({
		Name = "Màu Viền",
		Flag = "Chams_MauVien",
		Color = Color3.fromRGB(0, 255, 140),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				outlineColor = color
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

	chamsTab:Divider()

	-- ═══════════════════════════════════════════════════════════════
	-- NHÓM 4: MÀU NHÌN THẤY / ẨN NÚP
	-- ═══════════════════════════════════════════════════════════════
	
	chamsTab:Label({
		Name = "👁️ MÀU NHÌN THẤY / ẨN NÚP"
	})

	chamsTab:ColorPicker({
		Name = "Màu Nhìn Thấy (Nền)",
		Flag = "Chams_MauNhinThayNen",
		Color = Color3.fromRGB(0, 255, 0),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				visibleFillColor = color
			})
		end
	})

	chamsTab:ColorPicker({
		Name = "Màu Nhìn Thấy (Viền)",
		Flag = "Chams_MauNhinThayVien",
		Color = Color3.fromRGB(0, 255, 0),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				visibleOutlineColor = color
			})
		end
	})

	chamsTab:ColorPicker({
		Name = "Màu Ẩn Núp (Nền)",
		Flag = "Chams_MauAnNupNen",
		Color = Color3.fromRGB(255, 0, 0),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				hiddenFillColor = color
			})
		end
	})

	chamsTab:ColorPicker({
		Name = "Màu Ẩn Núp (Viền)",
		Flag = "Chams_MauAnNupVien",
		Color = Color3.fromRGB(255, 0, 0),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				hiddenOutlineColor = color
			})
		end
	})

	chamsTab:Divider()

	-- ═══════════════════════════════════════════════════════════════
	-- NHÓM 5: ĐỒNG ĐỘI
	-- ═══════════════════════════════════════════════════════════════
	
	chamsTab:Label({
		Name = "👥 ĐỒNG ĐỘI"
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
		Name = "Hiển Thị Đồng Đội",
		Flag = "Chams_HienDongDoi",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				showTeammates = value
			})
		end
	})

	chamsTab:ColorPicker({
		Name = "Màu Đồng Đội (Nền)",
		Flag = "Chams_MauDongDoiNen",
		Color = Color3.fromRGB(0, 150, 255),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				teammateFillColor = color
			})
		end
	})

	chamsTab:ColorPicker({
		Name = "Màu Đồng Đội (Viền)",
		Flag = "Chams_MauDongDoiVien",
		Color = Color3.fromRGB(0, 150, 255),
		Callback = function(color)
			ChamsAPI:UpdateConfig({
				teammateOutlineColor = color
			})
		end
	})

	chamsTab:Divider()

	-- ═══════════════════════════════════════════════════════════════
	-- NHÓM 6: HIỆU ỨNG CẦU VỒNG
	-- ═══════════════════════════════════════════════════════════════
	
	chamsTab:Label({
		Name = "🌈 CẦU VỒNG"
	})

	chamsTab:Slider({
		Name = "Tốc Độ Cầu Vồng",
		Flag = "Chams_TocDoCauVong",
		Min = 0.1,
		Max = 5,
		Default = 1,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				rainbowSpeed = value
			})
		end
	})

	chamsTab:Slider({
		Name = "Bão Hòa Cầu Vồng",
		Flag = "Chams_RainbowSat",
		Min = 0,
		Max = 1,
		Default = 1,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				rainbowSaturation = value
			})
		end
	})

	chamsTab:Slider({
		Name = "Độ Sáng Cầu Vồng",
		Flag = "Chams_RainbowVal",
		Min = 0,
		Max = 1,
		Default = 1,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				rainbowValue = value
			})
		end
	})

	chamsTab:Divider()

	-- ═══════════════════════════════════════════════════════════════
	-- NHÓM 7: HIỆU ỨNG ĐẬP
	-- ═══════════════════════════════════════════════════════════════
	
	chamsTab:Label({
		Name = "💓 ĐẬP (PULSE)"
	})

	chamsTab:Slider({
		Name = "Tốc Độ Đập",
		Flag = "Chams_TocDoDap",
		Min = 0.1,
		Max = 10,
		Default = 2,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				pulseSpeed = value
			})
		end
	})

	chamsTab:Slider({
		Name = "Min Đập",
		Flag = "Chams_PulseMin",
		Min = 0,
		Max = 1,
		Default = 0.6,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				pulseMinMultiplier = value
			})
		end
	})

	chamsTab:Slider({
		Name = "Max Đập",
		Flag = "Chams_PulseMax",
		Min = 0.5,
		Max = 2,
		Default = 1.4,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				pulseMaxMultiplier = value
			})
		end
	})

	chamsTab:Divider()

	-- ═══════════════════════════════════════════════════════════════
	-- NHÓM 8: HIỆU ỨNG CHUYỂN MÀU (GRADIENT)
	-- ═══════════════════════════════════════════════════════════════
	
	chamsTab:Label({
		Name = "🔄 CHUYỂN MÀU (GRADIENT)"
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

	chamsTab:Slider({
		Name = "Tốc Độ Chuyển Màu",
		Flag = "Chams_TocDoChuyenMau",
		Min = 0.1,
		Max = 5,
		Default = 1,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				gradientSpeed = value
			})
		end
	})

	chamsTab:Divider()

	-- ═══════════════════════════════════════════════════════════════
	-- NHÓM 9: HIỆU ỨNG MÁU
	-- ═══════════════════════════════════════════════════════════════
	
	chamsTab:Label({
		Name = "❤️ MÀU THEO MÁU"
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

	chamsTab:Divider()

	-- ═══════════════════════════════════════════════════════════════
	-- NHÓM 10: RAYCAST & MỜ DẦN
	-- ═══════════════════════════════════════════════════════════════
	
	chamsTab:Label({
		Name = "📡 RAYCAST & MỜ DẦN"
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
		Name = "Mờ Dần Theo Khoảng Cách",
		Flag = "Chams_MoDan",
		Default = false,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				distanceFadeEnabled = value
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

	chamsTab:Divider()

	-- ═══════════════════════════════════════════════════════════════
	-- NHÓM 11: HIỆU SUẤT
	-- ═══════════════════════════════════════════════════════════════
	
	chamsTab:Label({
		Name = "⚙️ HIỆU SUẤT"
	})

	chamsTab:Slider({
		Name = "Tốc Độ Cập Nhật (Batch)",
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
		Name = "Khoảng Cập Nhật (s)",
		Flag = "Chams_UpdateInterval",
		Min = 0.01,
		Max = 0.5,
		Default = 0.05,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				updateInterval = value
			})
		end
	})

	chamsTab:Divider()

	-- ═══════════════════════════════════════════════════════════════
	-- NHÓM 12: PHỤC HỒI LỖI & DEBUG
	-- ═══════════════════════════════════════════════════════════════
	
	chamsTab:Label({
		Name = "🔧 PHỤC HỒI LỖI & DEBUG"
	})

	chamsTab:Toggle({
		Name = "Tự Phục Hồi Lỗi",
		Flag = "Chams_PhucHoi",
		Default = false,
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

	chamsTab:Slider({
		Name = "Ngưỡng Phục Hồi Lỗi",
		Flag = "Chams_ErrorThreshold",
		Min = 1,
		Max = 20,
		Default = 5,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				errorRecoveryThreshold = value
			})
		end
	})

	chamsTab:Slider({
		Name = "Cooldown Phục Hồi (s)",
		Flag = "Chams_ErrorCooldown",
		Min = 1,
		Max = 10,
		Default = 3,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				errorRecoveryCooldown = value
			})
		end
	})

	chamsTab:Slider({
		Name = "Max Lỗi Liên Tiếp",
		Flag = "Chams_MaxErrors",
		Min = 1,
		Max = 50,
		Default = 10,
		Callback = function(value)
			ChamsAPI:UpdateConfig({
				maxConsecutiveErrors = value
			})
		end
	})

	chamsTab:Divider()

	-- ═══════════════════════════════════════════════════════════════
	-- NHÓM 13: HÀNH ĐỘNG
	-- ═══════════════════════════════════════════════════════════════
	
	chamsTab:Label({
		Name = "🔘 HÀNH ĐỘNG"
	})

	chamsTab:Button({
		Name = "🔄 Làm Mới Tất Cả",
		Callback = function()
			ChamsAPI:ForceUpdateAll()
		end
	})

	chamsTab:Button({
		Name = "🔧 Phục Hồi Lỗi",
		Callback = function()
			ChamsAPI:ForceRecovery()
		end
	})

	chamsTab:Button({
		Name = "🗑️ Đặt Lại Theo Dõi Lỗi",
		Callback = function()
			ChamsAPI:ResetErrorTracking()
		end
	})
end
