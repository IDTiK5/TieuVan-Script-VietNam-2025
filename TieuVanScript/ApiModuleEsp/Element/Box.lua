--[[
    BoxESP UI Module
    Handles all UI callbacks and integrations
    GitHub Ready
]]

local BoxESP_UI = {}

function BoxESP_UI:CreateUI(Section, API)
    local CONFIG = API.CONFIG
    
    -- ===== MAIN SETTINGS =====
    Section:Toggle({
        Name = "Enable Box ESP",
        Flag = "BoxESPToggle",
        Default = false,
        Callback = function(Value)
            CONFIG.Enabled = Value
        end
    })

    Section:Toggle({
        Name = "Show Self Box",
        Flag = "ShowSelfBox",
        Default = false,
        Callback = function(Value)
            CONFIG.ShowSelfBox = Value
        end
    })

    -- ===== BOX STYLING =====
    Section:Toggle({
        Name = "Inner Border",
        Flag = "InnerBorder",
        Default = false,
        Callback = function(Value)
            CONFIG.ShowInnerBorder = Value
        end
    })

    Section:Slider({
        Name = "Box Thickness",
        Flag = "BoxThickness",
        Min = 0.1,
        Max = 3,
        Default = 0.5,
        Decimals = 0.1,
        Suffix = "px",
        Callback = function(Value)
            CONFIG.BoxThickness = Value
            API:UpdateAllThickness()
        end
    })

    Section:Slider({
        Name = "Inner Thickness",
        Flag = "InnerThickness",
        Min = 0.1,
        Max = 3,
        Default = 0.5,
        Decimals = 0.1,
        Suffix = "px",
        Callback = function(Value)
            CONFIG.InnerThickness = Value
            API:UpdateAllThickness()
        end
    })

    Section:Label("Box Color"):Colorpicker({
        Name = "Box Color",
        Flag = "BoxColor",
        Default = Color3.fromRGB(255, 255, 255),
        Callback = function(Value)
            CONFIG.BoxColor = Value
        end
    })

    Section:Label("Self Box Color"):Colorpicker({
        Name = "Self Box Color",
        Flag = "SelfBoxColor",
        Default = Color3.fromRGB(255, 255, 255),
        Callback = function(Value)
            CONFIG.SelfBoxColor = Value
        end
    })

    -- ===== TEAM SETTINGS =====
    Section:Toggle({
        Name = "Team Check",
        Flag = "TeamCheck",
        Default = false,
        Callback = function(Value)
            CONFIG.EnableTeamCheck = Value
        end
    })

    Section:Toggle({
        Name = "Enemy Only",
        Flag = "EnemyOnly",
        Default = false,
        Callback = function(Value)
            CONFIG.ShowEnemyOnly = Value
        end
    })

    Section:Toggle({
        Name = "Use Team Colors",
        Flag = "UseTeamColors",
        Default = false,
        Callback = function(Value)
            CONFIG.UseTeamColors = Value
        end
    })

    Section:Toggle({
        Name = "Use Actual Team Colors",
        Flag = "UseActualTeamColors",
        Default = true,
        Callback = function(Value)
            CONFIG.UseActualTeamColors = Value
        end
    })

    Section:Label("Enemy Color"):Colorpicker({
        Name = "Enemy Color",
        Flag = "EnemyColor",
        Default = Color3.fromRGB(255, 0, 0),
        Callback = function(Value)
            CONFIG.EnemyBoxColor = Value
        end
    })

    Section:Label("Allied Color"):Colorpicker({
        Name = "Allied Color",
        Flag = "AlliedColor",
        Default = Color3.fromRGB(0, 255, 0),
        Callback = function(Value)
            CONFIG.AlliedBoxColor = Value
        end
    })

    Section:Label("No Team Color"):Colorpicker({
        Name = "No Team Color",
        Flag = "NoTeamColor",
        Default = Color3.fromRGB(255, 255, 255),
        Callback = function(Value)
            CONFIG.NoTeamColor = Value
        end
    })

    -- ===== GRADIENT SETTINGS =====
    Section:Toggle({
        Name = "Show Gradient",
        Flag = "ShowGradient",
        Default = false,
        Callback = function(Value)
            CONFIG.ShowGradient = Value
        end
    })

    Section:Toggle({
        Name = "Enable Gradient Animation",
        Flag = "GradientAnimation",
        Default = false,
        Callback = function(Value)
            CONFIG.EnableGradientAnimation = Value
            if Value then
                API:StartGradientAnimation()
            else
                API:StopGradientAnimation()
            end
        end
    })

    Section:Slider({
        Name = "Gradient Rotation",
        Flag = "GradientRotation",
        Min = 0,
        Max = 360,
        Default = 90,
        Decimals = 1,
        Suffix = "°",
        Callback = function(Value)
            CONFIG.GradientRotation = Value
            if not CONFIG.EnableGradientAnimation then
                for _, espData in pairs(API.STATE.espBoxes) do
                    if espData and espData.UIGradient then
                        espData.UIGradient.Rotation = Value
                    end
                end
            end
        end
    })

    Section:Slider({
        Name = "Gradient Animation Speed",
        Flag = "GradientSpeed",
        Min = 0.1,
        Max = 5,
        Default = 1,
        Decimals = 0.1,
        Suffix = "x",
        Callback = function(Value)
            CONFIG.GradientAnimationSpeed = Value
        end
    })

    Section:Slider({
        Name = "Gradient Transparency",
        Flag = "GradientTransparency",
        Min = 0,
        Max = 1,
        Default = 0.7,
        Decimals = 0.01,
        Callback = function(Value)
            CONFIG.GradientTransparency = Value
            API:UpdateAllGradients()
        end
    })

    Section:Label("Gradient Color 1"):Colorpicker({
        Name = "Gradient Color 1",
        Flag = "GradientColor1",
        Default = Color3.fromRGB(255, 86, 0),
        Callback = function(Value)
            CONFIG.GradientColor1 = Value
            API:UpdateAllGradients()
        end
    })

    Section:Label("Gradient Color 2"):Colorpicker({
        Name = "Gradient Color 2",
        Flag = "GradientColor2",
        Default = Color3.fromRGB(255, 0, 128),
        Callback = function(Value)
            CONFIG.GradientColor2 = Value
            API:UpdateAllGradients()
        end
    })
end

return BoxESP_UI
