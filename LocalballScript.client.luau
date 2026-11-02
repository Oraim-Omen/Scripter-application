local cs = game:GetService("CollectionService")
local rs = game:GetService("RunService")
local replicatedstorage = game:GetService("ReplicatedStorage")
local uis = game:GetService("UserInputService")

-- the module that keeps track of player states and the one that decides what they can do
local playerstats = require(replicatedstorage:WaitForChild("Scripts"):WaitForChild("PlayerStats"))
local canplayer = require(replicatedstorage:WaitForChild("Scripts"):WaitForChild("CanPlayer"))
local Inputs = require(replicatedstorage:WaitForChild("Scripts"):WaitForChild("InputManager"))
local contextactionutility = require(replicatedstorage:WaitForChild("Scripts"):WaitForChild("ContextActionUtility")) -- makes the mobile buttons (cancel charge, pass toggle)
-- since the script is inside of the tool this is a way to refrence everything else
local tool = script.Parent
--events yeah no point of explaining this
local throwevent = tool.Events:WaitForChild("ThrowEvent")
local chargingevent = tool.Events:WaitForChild("ChargingEvent")
local equipedevent = tool.Events:WaitForChild("EquipedEvent")

local player = game.Players.LocalPlayer
local character = player.Character
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

--local animate = script.Parent.Parent.Animate
local animator = humanoid:WaitForChild("Animator")
-- unlike my other movemnet script it doesn't use a module script also there is experimental stuff in here
-- the animations were implmented like this as a place holder
local chargingidle = Instance.new("Animation") -- idle animation for the ball charge
chargingidle.AnimationId = "rbxassetid://124974393266086"

local chargingmoving = Instance.new("Animation") -- animation for moveing 
chargingmoving.AnimationId = "rbxassetid://89751800707757"

local idleid = "rbxassetid://108632770456116" -- normal idle to go back to
local walkid =	"rbxassetid://95327723033692" -- normal walk to go back to

local cam = workspace.CurrentCamera

local target1 = nil -- the player that is locked on to
local passmode = false -- controls if the player is trying to pass to a teammate or throw to an enemy
local lastPassMode = passmode

local lastSeenTime = 0 -- counter
local SIGHT_LOSS_DELAY = 3 -- another counter to break the targeting
local lockin = 250 -- ditence the player have to be in to target som1
local FOV_DOT_THRESHOLD = 0.5 -- how far to the side of the camera a target can be

local drop = false -- true when the ball is dropped instead of thrown
local overhead = false -- the three throw types, all false means a direct throw
local rside = false
local lside = false

-- swaps the idle and walk animations for the charging ones
local function startChargeanimation()
	local transitionTime = 0.1

	for _, track in animator:GetPlayingAnimationTracks() do
        track:Stop(transitionTime)
    end
	script.Parent.Parent.Animate.idle.Animation1.AnimationId = chargingidle.AnimationId
	script.Parent.Parent.Animate.walk.WalkAnim.AnimationId = chargingmoving.AnimationId

	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
end

-- puts the normal idle and walk animations back
local function StopChargeanimation()
	local transitionTime = 0.1
	for _, track in animator:GetPlayingAnimationTracks() do
        track:Stop(transitionTime)
    end
		script.Parent.Parent.Animate.idle.Animation1.AnimationId = idleid
		script.Parent.Parent.Animate.walk.WalkAnim.AnimationId = walkid
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
end

-- finds the closest targetable character and if they are withen sight
local function findTarget(isPassMode)
   local targettag
	-- picks which team to look for, the enemy or the teammates
	if not isPassMode then
        if character:HasTag("MulberryTeam") then
            targettag = "GoldTeam"
        elseif character:HasTag("GoldTeam") then
            targettag = "MulberryTeam"
        end
    else
        if character:HasTag("MulberryTeam") then
            targettag = "MulberryTeam"
        elseif character:HasTag("GoldTeam") then
            targettag = "GoldTeam"
        end
    end
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {player.Character}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		local magnitudes = {}
	if not targettag then return end
		-- keeps the ones that are close enough, in front of the camera and not behind a wall
		for _, targets in pairs(cs:GetTagged(targettag)) do
			local direction = targets.HumanoidRootPart.Position - hrp.Position
			local dist = direction.Magnitude
			if dist < lockin and dist > 0 then
				local dot = cam.CFrame.LookVector:Dot(direction.Unit)
				if dot > FOV_DOT_THRESHOLD then
					local insight = workspace:Raycast(hrp.Position, direction, raycastParams)
					if insight and insight.Instance:IsDescendantOf(targets) then
						table.insert(magnitudes, targets)
					end
				end
			end
		end
			-- closest one goes first
			table.sort(magnitudes, function(a, b)
				return (hrp.Position - a.HumanoidRootPart.Position).Magnitude
					< (hrp.Position - b.HumanoidRootPart.Position).Magnitude
			end)
	return magnitudes[1] -- returns the cloest target
end
-- a functions to swich between the two teams
local function toggletarget()
	if passmode then
		passmode = false
	else
		passmode = true
	end
	return passmode
end
-- cancels the charge, used by the V key and the mobile cancel button
local function cancelcharge()
	if playerstats.GetState(player, "Charging") then
		playerstats.SetState(player, "Charging", false)
		StopChargeanimation()
		chargingevent:FireServer("cancel")
		if target1 and target1:FindFirstChild("Highlight") then
			target1.Highlight:Destroy()
		end
	end
end

-- MOBILE BUTTONS
-- they are only made while the ball is equipped (see Equipped and Unequipped below), so they only show when you are holding it
-- no keys are given to BindAction, so they only react to touch, the keyboard keeps using the handlers further down
-- while charging, a finger holds the screen, so the cancel button is pressed with a second finger
local function cancelaction(_, inputstate)
	if inputstate == Enum.UserInputState.Begin then
		cancelcharge()
	end
end

local function passaction(_, inputstate)
	if inputstate == Enum.UserInputState.Begin then
		toggletarget()
		contextactionutility:SetTitle("TogglePass", passmode and "Pass" or "Throw") -- the text shows the current mode
	end
end

local function addmobilebuttons()
	contextactionutility:BindAction("CancelCharge", cancelaction, true)
	contextactionutility:SetTitle("CancelCharge", "Cancel")

	contextactionutility:BindAction("TogglePass", passaction, true)
	contextactionutility:SetTitle("TogglePass", passmode and "Pass" or "Throw")
end

local function removemobilebuttons()
	contextactionutility:UnbindAction("CancelCharge")
	contextactionutility:UnbindAction("TogglePass")
end

--sets up after the ball/tool for that player
tool.Equipped:Connect(function()
	equipedevent:FireServer() -- tell the server the player has equipped the tool
	print("Tool equipped")
	addmobilebuttons()
end)
-- the player will drop the ball if they triad to have it in thair inventory
tool.Unequipped:Connect(function()
	drop = true
	throwevent:FireServer(drop)
	drop = false
	if target1 and target1:FindFirstChild("Highlight") then
		target1.Highlight:Destroy()
	end
	removemobilebuttons()
end)
-- the tool is destroyed when the player dies so the buttons are removed here too
humanoid.Died:Connect(removemobilebuttons)
-- player will starts charging up the ball/tool sending info to the serever till it is deactived
tool.Activated:Connect(function()
	playerstats.SetState(player, "Charging", true)
	startChargeanimation()
	target1 = findTarget(passmode)
	chargingevent:FireServer("start")
end)

-- V cancels the charge
uis.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if Inputs.Is(input, "CancelCharge") then
		cancelcharge()
	end
end)
-- swiching up the team to pass to, no ui in which the player targets
uis.InputBegan:Connect(function(input, gpe)
if gpe then return end
	if Inputs.Is(input, "TogglePass") then
		print("targetteamate")
		toggletarget()
    end
end)
-- keeps track of the targets and if they have a line of sight to the target
rs.Heartbeat:connect(function()
	local charging = playerstats.GetState(player, "Charging")
	-- if the team was switched the old target is removed
	if target1 and passmode ~= lastPassMode then
		if target1:FindFirstChild("Highlight") then
			target1.Highlight:Destroy()
		end
		target1 = nil
		lastSeenTime = 0
	end
	lastPassMode = passmode
	-- while charging the camera locks on to the target and they get a red outline
	if charging and target1 then
		local targetPos = target1.HumanoidRootPart.Position
		local currentPos = cam.CFrame.Position
		local lookCFrame = CFrame.lookAt(currentPos, targetPos)
		local raycastParams = RaycastParams.new()
		if target1:FindFirstChild("Highlight") == nil then
			local highlight = Instance.new("Highlight")
			highlight.Parent = target1
			highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
			highlight.FillTransparency = 1
		end
		raycastParams.FilterDescendantsInstances = {player.Character}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		local insight = workspace:Raycast(hrp.Position, targetPos, raycastParams)
		cam.CFrame = lookCFrame
		local currentTime = tick()
		-- if the target is hidden for too long the lock is dropped
		if insight and insight.Instance:IsDescendantOf(target1) then
			lastSeenTime = currentTime
		else
			if currentTime - lastSeenTime >= SIGHT_LOSS_DELAY then
				if target1:FindFirstChild("Highlight") then
					target1.Highlight:Destroy()
				end
				target1 = nil
				lastSeenTime = 0
			end
		end
	-- no target yet so it looks for one
	elseif charging and target1 == nil then
		target1 = findTarget(passmode)
		lastSeenTime = tick()
	end
end)
-- works out the throw type from the direction the player is moving compared to where they face
local function updateThrowDirection()
	local move = hrp.CFrame:VectorToObjectSpace(humanoid.MoveDirection)
	overhead, rside, lside = false, false, false
	if move.Magnitude < 0.1 then return end -- standing still is a direct throw
	if math.abs(move.X) > math.abs(move.Z) then
		if move.X > 0 then
			rside = true
		else
			lside = true
		end
	elseif move.Z > 0 then
		overhead = true -- moving backwards
	end
	-- moving forward leaves everything false which is a direct throw
end

-- throws the ball and truns to normal state
tool.Deactivated:Connect(function()
	local charging = playerstats.GetState(player, "Charging")
	if not target1 and charging then return end
	-- only throws if the player is allowed to
	if canplayer.CanThrow(player) and charging then
		script.Parent.Parent.Animate.idle.Animation1.AnimationId = idleid
		if target1 then
			target1:FindFirstChild("Highlight"):Destroy()
		end
		StopChargeanimation() -- stops the charging animations and returns the deafults
		playerstats.SetState(player, "Charging", false)
		print("deactivted")
		print(target1)
		updateThrowDirection() -- checks which way the player is moving right as they throw
		throwevent:FireServer(drop, overhead, rside, lside, target1)
		target1 = nil
    end
end)
