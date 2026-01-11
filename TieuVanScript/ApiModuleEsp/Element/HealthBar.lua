--[[
    HealthBar UI Module
    Handles all UI callbacks and integrations
    GitHub Ready
]]

local HealthBar_UI = {}

function HealthBar_UI:CreateUI(Section, API)
    local CONFIG = API.CONFIG
    
    -- ===== MAIN SETTINGS =====
    Section:Toggle({
        Name = "Enable Health Bar",
        Flag = "HealthBarToggle",
        Default = false,
        Callback = function(Value)
            CONFIG.Enabled = Value
        end
    })

    Section:Toggle({
        Name = "Show Self Health Bar",
        Flag = "ShowSelfHealthBar",
        Default = false,
        Callback = function(Value)
            CONFIG.ShowSelfHealthBar = Value
        end
    })

    -- ===== POSITIONING =====
    Section:Dropdown({
        Name = "Position",
        Flag = "HealthBarSide",
        Default = "Left",
        Items = {"Left", "Right"},
        Multi = false,
        Callback = function(Value)
            CONFIG.Side = Value
        end
    })

    Section:Slider({
        Name = "Offset X",
        Flag = "OffsetX",
        Min = -50,
        Max = 100,
        Default = 0,
        Decimals = 0.1,
        Suffix = "px",
        Callback = function(Value)
            CONFIG.OffsetX = Value
        end
    })

    Section:Slider({
        Name = "Offset Y",
        Flag = "OffsetY",
        Min = -50,
        Max = 100,
        Default = 0,
        Decimals = 0.1,
        Suffix = "px",
        Callback = function(Value)
            CONFIG.OffsetY = Value
        end
    })

    Section:Slider({
        Name = "Gap Distance",
        Flag = "HealthBarGap",
        Min = 0,
        Max = 20,
        Default = 2,
        Decimals = 0.1,
        Suffix = "px",
        Callback = function(Value)
            CONFIG.HealthBarGap = Value
        end
    })

    Section:Slider({
        Name = "Bar Width",
        Flag = "HealthBarWidth",
        Min = 1,
        Max = 10,
        Default = 3,
        Decimals = 0.1,
        Suffix = "px",
        Callback = function(Value)
            CONFIG.HealthBarWidth = Value
        end
    })

    -- ===== ANIMATION =====
    Section:Slider({
        Name = "Animation Speed",
        Flag = "AnimationSpeed",
        Min = 0.1,
        Max = 1,
        Default = 0.3,
        Decimals = 2,
        Suffix = "s",
        Callback = function(Value)
            CONFIG.AnimationSpeed = Value
        end
    })

    Section:Toggle({
        Name = "Enable Flash Effect",
        Flag = "EnableFlashEffect",
        Default = true,
        Callback = function(Value)
            CONFIG.EnableFlashEffect = Value
        end
    })

    Section:Slider({
        Name = "Flash Duration",
        Flag = "FlashDuration",
        Min = 0.05,
        Max = 0.5,
        Default = 0.15,
        Decimals = 2,
        Suffix = "s",
        Callback = function(Value)
            CONFIG.FlashDuration = Value
        end
    })

    Section:Label("Damage Flash Color"):Colorpicker({
        Name = "Damage Flash Color",
        Flag = "DamageFlashColor",
        Default = Color3.fromRGB(255, 0, 0),
        Callback = function(Value)
            CONFIG.DamageFlashColor = Value
        end
    })

    Section:Label("Heal Flash Color"):Colorpicker({
        Name = "Heal Flash Color",
        Flag = "HealFlashColor",
        Default = Color3.fromRGB(0, 255, 100),
        Callback = function(Value)
            CONFIG.HealFlashColor = Value
        end
    })

    -- ===== TEAM SETTINGS =====
    Section:Toggle({
        Name = "Team Check",
        Flag = "HealthTeamCheck",
        Default = false,
        Callback = function(Value)
            CONFIG.EnableTeamCheck = Value
        end
    })

    Section:Toggle({
        Name = "Enemy Only",
        Flag = "HealthEnemyOnly",
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

    -- ===== COLORS =====
    Section:Label("Enemy Color"):Colorpicker({
        Name = "Enemy Health Color",
        Flag = "EnemyHealthColor",
        Default = Color3.fromRGB(180, 0, 255),
        Callback = function(Value)
            CONFIG.EnemyHealthBarColor = Value
        end
    })

    Section:Label("Allied Color"):Colorpicker({
        Name = "Allied Health Color",
        Flag = "AlliedHealthColor",
        Default = Color3.fromRGB(0, 255, 0),
        Callback = function(Value)
            CONFIG.AlliedHealthBarColor = Value
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
end

return HealthBar_UI
