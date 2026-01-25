return function(PlayerPage, CameraAPI)
	local CameraSection = PlayerPage:Section({
		Name = "Camera",
		Description = "Camera Settings",
		Icon = "133029797251962",
		Side = 2
	})

	--=============================================================================
	-- SPECTATE MODE
	--=============================================================================

	CameraSection:Toggle({
		Name = "Spectate Mode",
		Flag = "SpectateMode",
		Default = false,
		Callback = function(Value)
			if Value then
				CameraAPI:EnableSpectate()
			else
				CameraAPI:DisableSpectate()
			end
		end
	})

	CameraSection:Slider({
		Name = "Spectate Speed",
		Flag = "SpectateSpeed",
		Min = 10,
		Max = 500,
		Default = 50,
		Decimals = 1,
		Suffix = " studs/s",
		Callback = function(Value)
			CameraAPI:SetSpectateSpeed(Value)
		end
	})

	--=============================================================================
	-- UNLOCK CAMERA
	--=============================================================================

	CameraSection:Toggle({
		Name = "Unlock Camera",
		Flag = "UnlockCamera",
		Default = false,
		Callback = function(Value)
			if Value then
				CameraAPI:EnableUnlockCamera()
			else
				CameraAPI:DisableUnlockCamera()
			end
		end
	})

	CameraSection:Slider({
		Name = "Max Zoom Distance",
		Flag = "MaxZoomDistance",
		Min = 10,
		Max = 50000,
		Default = 128,
		Decimals = 1,
		Suffix = " studs",
		Callback = function(Value)
			CameraAPI:SetMaxZoomDistance(Value)
		end
	})

	--=============================================================================
	-- SHIFT LOCK
	--=============================================================================

	CameraSection:Toggle({
		Name = "Shift Lock",
		Flag = "ShiftLock",
		Default = false,
		Callback = function(Value)
			if Value then
				CameraAPI:EnableShiftLock()
			else
				CameraAPI:DisableShiftLock()
			end
		end
	})

	--=============================================================================
	-- FIRST PERSON MODE
	--=============================================================================

	CameraSection:Toggle({
		Name = "First Person Mode",
		Flag = "FirstPersonMode",
		Default = false,
		Callback = function(Value)
			if Value then
				CameraAPI:EnableFirstPerson()
			else
				CameraAPI:DisableFirstPerson()
			end
		end
	})

	--=============================================================================
	-- FIELD OF VIEW
	--=============================================================================

	CameraSection:Slider({
		Name = "Field of View (FOV)",
		Flag = "CameraFOV",
		Min = 30,
		Max = 120,
		Default = 70,
		Decimals = 1,
		Suffix = "°",
		Callback = function(Value)
			CameraAPI:SetFieldOfView(Value)
		end
	})

	--=============================================================================
	-- CAMERA TYPE
	--=============================================================================

	CameraSection:Dropdown({
		Name = "Camera Type",
		Flag = "CameraType",
		Default = "Custom",
		Items = {"Custom", "Follow", "Orbital", "Track"},
		Multi = false,
		Callback = function(Value)
			local cameraType = type(Value) == "table" and Value[1] or Value
			CameraAPI:SetCameraType(cameraType)
		end
	})

	--=============================================================================
	-- NO CLIP CAMERA
	--=============================================================================

	CameraSection:Toggle({
		Name = "No Clip Camera",
		Flag = "NoClipCamera",
		Default = false,
		Callback = function(Value)
			if Value then
				CameraAPI:EnableNoClipCamera()
			else
				CameraAPI:DisableNoClipCamera()
			end
		end
	})

	--=============================================================================
	-- SMOOTH CAMERA
	--=============================================================================

	CameraSection:Toggle({
		Name = "Smooth Camera",
		Flag = "SmoothCamera",
		Default = false,
		Callback = function(Value)
			if Value then
				CameraAPI:EnableSmoothCamera()
			else
				CameraAPI:DisableSmoothCamera()
			end
		end
	})

	CameraSection:Slider({
		Name = "Camera Sensitivity",
		Flag = "CameraSensitivity",
		Min = 0.1,
		Max = 3,
		Default = 1,
		Decimals = 0.1,
		Suffix = "x",
		Callback = function(Value)
			CameraAPI:SetCameraSensitivity(Value)
		end
	})

	--=============================================================================
	-- CAMERA OFFSET
	--=============================================================================

	CameraSection:Slider({
		Name = "Camera Offset X",
		Flag = "CameraOffsetX",
		Min = -5,
		Max = 5,
		Default = 0,
		Decimals = 0.1,
		Callback = function(Value)
			CameraAPI:SetCameraOffsetX(Value)
		end
	})

	CameraSection:Slider({
		Name = "Camera Offset Y",
		Flag = "CameraOffsetY",
		Min = -5,
		Max = 5,
		Default = 0,
		Decimals = 0.1,
		Callback = function(Value)
			CameraAPI:SetCameraOffsetY(Value)
		end
	})

	CameraSection:Slider({
		Name = "Camera Offset Z",
		Flag = "CameraOffsetZ",
		Min = -5,
		Max = 5,
		Default = 0,
		Decimals = 0.1,
		Callback = function(Value)
			CameraAPI:SetCameraOffsetZ(Value)
		end
	})
end
