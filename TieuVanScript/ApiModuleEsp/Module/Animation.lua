local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

--=============================================================================
-- STATE
--=============================================================================

local originalAnimations = {}
local hasStoredOriginal = false
local selectedAnimation = "Default"

--=============================================================================
-- ANIMATIONS DATABASE
--=============================================================================

local animations = {
	["Default"] = nil,
	["Adidas"] = {
		idle = {Animation1 = 122257458498464, Animation2 = 102357151005774},
		walk = {WalkAnim = 122150855457006},
		run = {RunAnim = 82598234841035},
		jump = {JumpAnim = 75290611992385},
		swim = {Swim = 133308483266208},
		swimidle = {SwimIdle = 109346520324160},
		climb = {ClimbAnim = 88763136693023},
		fall = {FallAnim = 98600215928904}
	},
	["Oldschool"] = {
		idle = {Animation1 = 10921230744, Animation2 = 10921232093},
		walk = {WalkAnim = 10921244891},
		run = {RunAnim = 10921240218},
		jump = {JumpAnim = 10921242013},
		swim = {Swim = 10921243048},
		swimidle = {SwimIdle = 10921244018},
		climb = {ClimbAnim = 10921229866},
		fall = {FallAnim = 10921241244}
	},
	["Robot"] = {
		idle = {Animation1 = 10921248039, Animation2 = 10921248831},
		walk = {WalkAnim = 10921255446},
		run = {RunAnim = 10921250460},
		jump = {JumpAnim = 10921252123},
		swim = {Swim = 10921253142},
		swimidle = {SwimIdle = 10921253767},
		climb = {ClimbAnim = 10921247141},
		fall = {FallAnim = 10921251156}
	},
	["Cartoony"] = {
		idle = {Animation1 = 10921071918, Animation2 = 10921072875},
		walk = {WalkAnim = 10921082452},
		run = {RunAnim = 10921076136},
		jump = {JumpAnim = 10921078135},
		swim = {Swim = 10921079380},
		swimidle = {SwimIdle = 10921081059},
		climb = {ClimbAnim = 10921070953},
		fall = {FallAnim = 10921077030}
	},
	["Adidas Aura"] = {
		idle = {Animation1 = 110211186840347, Animation2 = 114191137265065},
		walk = {WalkAnim = 83842218823011},
		run = {RunAnim = 118320322718866},
		jump = {JumpAnim = 109996626521204},
		swim = {Swim = 134530128383903},
		swimidle = {SwimIdle = 94922130551805},
		climb = {ClimbAnim = 97824616490448},
		fall = {FallAnim = 95603166884636}
	},
	["Stylish"] = {
		idle = {Animation1 = 10921272275, Animation2 = 10921273958},
		walk = {WalkAnim = 10921283326},
		run = {RunAnim = 10921276116},
		jump = {JumpAnim = 10921279832},
		swim = {Swim = 10921281000},
		swimidle = {SwimIdle = 10921281964},
		climb = {ClimbAnim = 10921271391},
		fall = {FallAnim = 10921278648}
	},
	["Mage"] = {
		idle = {Animation1 = 10921144709, Animation2 = 10921145797},
		walk = {WalkAnim = 10921152678},
		run = {RunAnim = 10921148209},
		jump = {JumpAnim = 10921149743},
		swim = {Swim = 10921150788},
		swimidle = {SwimIdle = 10921151661},
		climb = {ClimbAnim = 10921143404},
		fall = {FallAnim = 10921148939}
	},
	["Bold"] = {
		idle = {Animation1 = 16738333868, Animation2 = 16738334710},
		walk = {WalkAnim = 16738340646},
		run = {RunAnim = 16738337225},
		jump = {JumpAnim = 16738336650},
		swim = {Swim = 16738339158},
		swimidle = {SwimIdle = 16738339817},
		climb = {ClimbAnim = 16738332169},
		fall = {FallAnim = 16738333171}
	},
	["Toy"] = {
		idle = {Animation1 = 10921301576, Animation2 = 10921302207},
		walk = {WalkAnim = 10921312010},
		run = {RunAnim = 10921306285},
		jump = {JumpAnim = 10921308158},
		swim = {Swim = 10921309319},
		swimidle = {SwimIdle = 10921310341},
		climb = {ClimbAnim = 10921300839},
		fall = {FallAnim = 10921307241}
	},
	["Adidas Sports"] = {
		idle = {Animation1 = 18537376492, Animation2 = 18537371272},
		walk = {WalkAnim = 18537392113},
		run = {RunAnim = 18537384940},
		jump = {JumpAnim = 18537380791},
		swim = {Swim = 18537389531},
		swimidle = {SwimIdle = 18537387180},
		climb = {ClimbAnim = 18537363391},
		fall = {FallAnim = 18537367238}
	},
	["Wicked Dancing Through Life"] = {
		idle = {Animation1 = 92849173543269, Animation2 = 132238900951109},
		walk = {WalkAnim = 73718308412641},
		run = {RunAnim = 135515454877967},
		jump = {JumpAnim = 78508480717326},
		swim = {Swim = 110657013921774},
		swimidle = {SwimIdle = 129183123083281},
		climb = {ClimbAnim = 129447497744818},
		fall = {FallAnim = 78147885297412}
	},
	["Wicked Popular"] = {
		idle = {Animation1 = 118832222982049, Animation2 = 76049494037641},
		walk = {WalkAnim = 92072849924640},
		run = {RunAnim = 72301599441680},
		jump = {JumpAnim = 104325245285198},
		swim = {Swim = 99384245425157},
		swimidle = {SwimIdle = 113199415118199},
		climb = {ClimbAnim = 131326830509784},
		fall = {FallAnim = 121152442762481}
	},
	["Catwalk Glam"] = {
		idle = {Animation1 = 133806214992291, Animation2 = 94970088341563},
		walk = {WalkAnim = 109168724482748},
		run = {RunAnim = 81024476153754},
		jump = {JumpAnim = 116936326516985},
		swim = {Swim = 134591743181628},
		swimidle = {SwimIdle = 98854111361360},
		climb = {ClimbAnim = 119377220967554},
		fall = {FallAnim = 92294537340807}
	},
	["Zombie"] = {
		idle = {Animation1 = 10921344533, Animation2 = 10921345304},
		walk = {WalkAnim = 10921355261},
		run = {RunAnim = 616163682},
		jump = {JumpAnim = 10921351278},
		swim = {Swim = 10921352344},
		swimidle = {SwimIdle = 10921353442},
		climb = {ClimbAnim = 10921343576},
		fall = {FallAnim = 10921350320}
	},
	["Superhero"] = {
		idle = {Animation1 = 10921288909, Animation2 = 10921290167},
		walk = {WalkAnim = 10921298616},
		run = {RunAnim = 10921291831},
		jump = {JumpAnim = 10921294559},
		swim = {Swim = 10921295495},
		swimidle = {SwimIdle = 10921297391},
		climb = {ClimbAnim = 10921286911},
		fall = {FallAnim = 10921293373}
	},
	["No Boundaries"] = {
		idle = {Animation1 = 18747067405, Animation2 = 18747063918},
		walk = {WalkAnim = 18747074203},
		run = {RunAnim = 18747070484},
		jump = {JumpAnim = 18747069148},
		swim = {Swim = 18747073181},
		swimidle = {SwimIdle = 18747071682},
		climb = {ClimbAnim = 18747060903},
		fall = {FallAnim = 18747062535}
	},
	["Amazon Unboxed"] = {
		idle = {Animation1 = 18747067405, Animation2 = 18747063918},
		walk = {WalkAnim = 18747074203},
		run = {RunAnim = 18747070484},
		jump = {JumpAnim = 18747069148},
		swim = {Swim = 18747073181},
		swimidle = {SwimIdle = 18747071682},
		climb = {ClimbAnim = 18747060903},
		fall = {FallAnim = 18747062535}
	},
	["Elder"] = {
		idle = {Animation1 = 10921101664, Animation2 = 10921102574},
		walk = {WalkAnim = 10921111375},
		run = {RunAnim = 10921104374},
		jump = {JumpAnim = 10921107367},
		swim = {Swim = 10921108971},
		swimidle = {SwimIdle = 10921110146},
		climb = {ClimbAnim = 10921100400},
		fall = {FallAnim = 10921105765}
	},
	["Vampire"] = {
		idle = {Animation1 = 10921315373, Animation2 = 10921316709},
		walk = {WalkAnim = 10921326949},
		run = {RunAnim = 10921320299},
		jump = {JumpAnim = 10921322186},
		swim = {Swim = 10921324408},
		swimidle = {SwimIdle = 10921325443},
		climb = {ClimbAnim = 10921314188},
		fall = {FallAnim = 10921321317}
	},
	["Bubbly"] = {
		idle = {Animation1 = 10921054344, Animation2 = 10921055107},
		walk = {WalkAnim = 10980888364},
		run = {RunAnim = 10921057244},
		jump = {JumpAnim = 10921062673},
		swim = {Swim = 10921063569},
		swimidle = {SwimIdle = 10922582160},
		climb = {ClimbAnim = 10921053544},
		fall = {FallAnim = 10921061530}
	},
	["Ninja"] = {
		idle = {Animation1 = 10921155160, Animation2 = 10921155867},
		walk = {WalkAnim = 10921162768},
		run = {RunAnim = 10921157929},
		jump = {JumpAnim = 10921160088},
		swim = {Swim = 10921161002},
		swimidle = {SwimIdle = 10922757002},
		climb = {ClimbAnim = 10921154678},
		fall = {FallAnim = 10921159222}
	},
	["Knight"] = {
		idle = {Animation1 = 10921117521, Animation2 = 10921118894},
		walk = {WalkAnim = 10921127095},
		run = {RunAnim = 10921121197},
		jump = {JumpAnim = 10921123517},
		swim = {Swim = 10921125160},
		swimidle = {SwimIdle = 10921125935},
		climb = {ClimbAnim = 10921116196},
		fall = {FallAnim = 10921122579}
	},
	["NFL"] = {
		idle = {Animation1 = 92080889861410, Animation2 = 74451233229259},
		walk = {WalkAnim = 110358958299415},
		run = {RunAnim = 117333533048078},
		jump = {JumpAnim = 119846112151352},
		swim = {Swim = 132697394189921},
		swimidle = {SwimIdle = 79090109939093},
		climb = {ClimbAnim = 134630013742019},
		fall = {FallAnim = 129773241321032}
	},
	["Werewolf"] = {
		idle = {Animation1 = 10921330408, Animation2 = 10921333667},
		walk = {WalkAnim = 10921342074},
		run = {RunAnim = 10921336997},
		jump = {JumpAnim = 1083218792},
		swim = {Swim = 10921340419},
		swimidle = {SwimIdle = 10921341319},
		climb = {ClimbAnim = 10921329322},
		fall = {FallAnim = 10921337907}
	},
	["Astronaut"] = {
		idle = {Animation1 = 10921034824, Animation2 = 10921036806},
		walk = {WalkAnim = 10921046031},
		run = {RunAnim = 10921039308},
		jump = {JumpAnim = 10921042494},
		swim = {Swim = 10921044000},
		swimidle = {SwimIdle = 10921045006},
		climb = {ClimbAnim = 10921032124},
		fall = {FallAnim = 10921040576}
	},
	["Levitation"] = {
		idle = {Animation1 = 10921132962, Animation2 = 10921133721},
		walk = {WalkAnim = 10921140719},
		run = {RunAnim = 10921135644},
		jump = {JumpAnim = 10921137402},
		swim = {Swim = 10921138209},
		swimidle = {SwimIdle = 10921139478},
		climb = {ClimbAnim = 10921132092},
		fall = {FallAnim = 10921136539}
	},
	["Pirate"] = {
		idle = {Animation1 = 750781874, Animation2 = 750782770},
		walk = {WalkAnim = 750785693},
		run = {RunAnim = 750783738},
		jump = {JumpAnim = 750782230},
		swim = {Swim = 750784579},
		swimidle = {SwimIdle = 750785176},
		climb = {ClimbAnim = 750779899},
		fall = {FallAnim = 750780242}
	},
	["Rthro"] = {
		idle = {Animation1 = 10921258489, Animation2 = 10921259953},
		walk = {WalkAnim = 10921269718},
		run = {RunAnim = 10921261968},
		jump = {JumpAnim = 10921263860},
		swim = {Swim = 10921264784},
		swimidle = {SwimIdle = 10921265698},
		climb = {ClimbAnim = 10921257536},
		fall = {FallAnim = 10921262864}
	}
}

--=============================================================================
-- UTILITY FUNCTIONS
--=============================================================================

local function getAnimationNames()
	local names = {}
	for name, _ in pairs(animations) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

local function storeOriginalAnimations(animate)
	if hasStoredOriginal then return end
	
	for _, child in pairs(animate:GetChildren()) do
		if child:IsA("Folder") or child:IsA("StringValue") then
			originalAnimations[child.Name] = {}
			for _, anim in pairs(child:GetChildren()) do
				if anim:IsA("Animation") then
					originalAnimations[child.Name][anim.Name] = anim.AnimationId
				end
			end
		end
	end
	
	hasStoredOriginal = true
end

local function forceRefreshAnimations(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in pairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0)
		end
	end
	
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate.Disabled = true
		task.wait()
		animate.Disabled = false
	end
	
	task.wait(0.1)
	humanoid:ChangeState(Enum.HumanoidStateType.Landed)
end

local function applyAnimations(animSet)
	local character = LocalPlayer.Character
	if not character then return end
	
	local animate = character:FindFirstChild("Animate")
	if not animate then return end
	
	storeOriginalAnimations(animate)
	
	for folderName, anims in pairs(animSet) do
		local folder = animate:FindFirstChild(folderName)
		if folder and (folder:IsA("Folder") or folder:IsA("StringValue")) then
			for animName, animId in pairs(anims) do
				local anim = folder:FindFirstChild(animName)
				if anim and anim:IsA("Animation") then
					anim.AnimationId = "rbxassetid://" .. tostring(animId)
				end
			end
		end
	end
	
	forceRefreshAnimations(character)
end

local function restoreOriginalAnimations()
	local character = LocalPlayer.Character
	if not character then return end
	
	local animate = character:FindFirstChild("Animate")
	if not animate then return end
	
	if not (next(originalAnimations) == nil) then
		for folderName, anims in pairs(originalAnimations) do
			local folder = animate:FindFirstChild(folderName)
			if folder and (folder:IsA("Folder") or folder:IsA("StringValue")) then
				for animName, animId in pairs(anims) do
					local anim = folder:FindFirstChild(animName)
					if anim and anim:IsA("Animation") then
						anim.AnimationId = animId
					end
				end
			end
		end
	end
	
	forceRefreshAnimations(character)
end

--=============================================================================
-- CHARACTER RESPAWN HANDLER
--=============================================================================

LocalPlayer.CharacterAdded:Connect(function(character)
	task.wait(1)
	hasStoredOriginal = false
	originalAnimations = {}
	
	local animate = character:FindFirstChild("Animate")
	if animate then
		storeOriginalAnimations(animate)
	end
	
	if selectedAnimation ~= "Default" then
		changeAnimation(selectedAnimation)
	end
end)

if LocalPlayer.Character then
	task.spawn(function()
		task.wait(0.5)
		local animate = LocalPlayer.Character:FindFirstChild("Animate")
		if animate then
			storeOriginalAnimations(animate)
		end
	end)
end

--=============================================================================
-- PUBLIC API
--=============================================================================

local AnimationAPI = {}

function AnimationAPI:GetAnimationList()
	return getAnimationNames()
end

function AnimationAPI:GetCurrentAnimation()
	return selectedAnimation
end

function AnimationAPI:ChangeAnimation(animName)
	selectedAnimation = animName
	
	if animName == "Default" then
		restoreOriginalAnimations()
	else
		local animSet = animations[animName]
		if animSet then
			applyAnimations(animSet)
		end
	end
end

function AnimationAPI:AddCustomAnimation(name, animData)
	if animations[name] then
		return false
	end
	animations[name] = animData
	return true
end

function AnimationAPI:RemoveCustomAnimation(name)
	if name == "Default" or not animations[name] then
		return false
	end
	animations[name] = nil
	return true
end

function AnimationAPI:GetAnimation(name)
	return animations[name]
end

function AnimationAPI:SetAnimation(name, animData)
	if name == "Default" then
		return false
	end
	animations[name] = animData
	return true
end

function AnimationAPI:RestoreDefault()
	restoreOriginalAnimations()
	selectedAnimation = "Default"
end

return AnimationAPI
