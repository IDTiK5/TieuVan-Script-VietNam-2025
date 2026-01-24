return function(Player2Page, AnimationAPI)
	local AnimationSection = Player2Page:Section({
		Name = "Animation Changer",
		Description = "Change your character animations",
		Icon = "10734923549",
		Side = 1
	})

	AnimationSection:Listbox({
		Name = "Select Animation",
		Flag = "AnimationListbox",
		Default = "Default",
		Items = AnimationAPI:GetAnimationList(),
		Size = 275,
		Multi = false,
		Callback = function(Value)
			local animName = type(Value) == "table" and Value[1] or Value
			AnimationAPI:ChangeAnimation(animName)
		end
	})

	AnimationSection:Button({
		Name = "Restore Default",
		Callback = function()
			AnimationAPI:RestoreDefault()
		end
	})
end
