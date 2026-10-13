local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local replicatedstorage = game:GetService("ReplicatedStorage")
local tweenservice = game:GetService("TweenService")
local soundservice = game:GetService("SoundService")
local starterplayer = game:GetService("StarterPlayer")

local events = replicatedstorage:WaitForChild("events")

local tackleevent = events:WaitForChild("TackleEvent")
local velocityevent = events:WaitForChild("VelocityEvent")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local Rootpart = character:WaitForChild("HumanoidRootPart")
local Head = character:FindFirstChild("Head")
local rarm = character:FindFirstChild("Right Arm")
local larm = character:FindFirstChild("Left Arm")
local torso = character:FindFirstChild("Torso")

local tweeninfo = TweenInfo.new(0.05) -- used to snap the player onto a ledge

local scripts = replicatedstorage:WaitForChild("Scripts")
local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator")
--modules
local playerstats = require(scripts:WaitForChild("PlayerStats")) -- keeps the player's states (Dashing, Sliding, Hanging...)
local canplayer = require(scripts:WaitForChild("CanPlayer")) -- checks if an action is allowed right now (CanDash, CanSlide...)
local soundmanager = require(scripts:WaitForChild("SoundManager")) -- plays sounds through the server so everyone hears them
local anims = require(script.Parent:WaitForChild("AnimationData"))(animator) -- loads all the animation tracks

local linearvelocity = Rootpart:WaitForChild("LinearVelocity") -- constraint in the root part that moves the player for dashes, slides and ledge hangs
-- values for balancing 
local acc = 3         -- walkspeed gained every 0.1s while running
local deacc = 0.5     -- walkspeed lost every 0.1s while slowing down
local runningspeed = 50
local ledgegrabdistence = 6
-- shorter names for the animations from the module
local slidetrack = anims.Slide
local slidingtrack = anims.Sliding
local getuptrack = anims.Getup
local ledgehangtrack = anims.LedgeHang
local Hangingtrack = anims.Hanging
local pulluptrack = anims.pullup
local vaulttrack = anims.Vault
local kneetucktrack = anims.KneeTuck
local Fdashtrack = anims.FDash
local Bdashtrack = anims.BDash
local Rdashtrack = anims.Rdash
local ldashtrack = anims.Ldash
local catchattempttrack = anims.CatchAttempt -- catch stance, before the ball arrives
local catchtrack = anims.Catch               -- successful catch on the ground
local aircatchtrack = anims.AirCatch         -- catch stance in the air
local aircatchedtrack = anims.ArialCatched   -- successful catch in the air
local Tackletrack = anims.Tackle
local Fbumbtrack = anims.FBumb               -- bump animations: front, back, right, left
local Bbumptrack = anims.BBump
local Rbumptrack = anims.RBump
local Lbumptrack = anims.LBump
local crouchitrack = anims.Crouchi           -- crouch idle
local crouchmmtrack = anims.CrouchM          -- crouch moving
local rwallkicktrack = anims.RWallKick
local lwallkicktrack = anims.LWallKick
local unbalancetrack = anims.Unbalance


local jump = soundservice:WaitForChild("Jump")
local jumpv = soundservice:WaitForChild("JumpV")
local land = soundservice:WaitForChild("Land")
local rubberImpact = soundservice:WaitForChild("RubberImpact")
local grab = soundservice:WaitForChild("Grab")
local slide = soundservice:WaitForChild("Sliding")

local baseSpeed = starterplayer.CharacterWalkSpeed
local currentspeed = humanoid.WalkSpeed -- remembered so the slide can start from the running speed

playerstats.ClearAllStats(player) -- clears leftover states in case the last session didn't
playerstats.SetState(player, "CanSlide", true) -- allows sliding from the start
-- these are only used in this script so they aren't in the playerstats module
local running = false
local inair = false
local iscroching = false
local ismoving = false
local hitby -- whatever last hit the player, handleImpact ignores it so the player doesn't bump into it

-- re-grabs the LinearVelocity after a respawn
local function setupHumanoid(_)
	linearvelocity = Rootpart:WaitForChild("LinearVelocity")
end 
-- inair is true while there is no floor under the humanoid
humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
	inair = humanoid.FloorMaterial == Enum.Material.Air
end)
-- plays the crouch walk animation only while crouching and moving
local function updateCrouchAnimation()
	if iscroching and ismoving then
		crouchmmtrack:Play()
	else
		crouchmmtrack:Stop()
	end
end
-- keeps ismoving up to date and refreshes the crouch animation
humanoid.Running:Connect(function()
	ismoving = humanoid.MoveDirection.Magnitude > 0
	updateCrouchAnimation()
end)
-- ends a normal dash: stops the player and gives control back
local function dashend()
if playerstats.GetState(player, "Bumbed") then return end -- handleImpact ends the dash instead if the player bumped into something
	soundmanager.EmitServer(land, Rootpart)
	linearvelocity.VectorVelocity = Vector3.new(0, 0, 0)
	humanoid.AutoRotate = true
	linearvelocity.Enabled = false
	playerstats.SetState(player, "Dashing", false, nil)
end
-- cancels a dash early (dash pressed again while already dashing)
local function dashinterput()
	if not playerstats.GetState(player, "Bumbed") then
		unbalancetrack:Stop()
		playerstats.SetState(player, "Unbalanced", false)
		linearvelocity.VectorVelocity = Vector3.new(0, 0, 0)
		linearvelocity.Enabled = false
		playerstats.SetState(player, "Dashing", false)
		playerstats.SetState(player, "CanCatch", false) -- no catching right after a cancelled dash
		soundmanager.EmitServer(land, Rootpart)
		Fdashtrack:Stop()
	end
	humanoid.AutoRotate = true
end
-- starts a dash in the given direction with the given animation
local function dash(direction, track)
	-- pressing dash again while dashing cancels it
	if playerstats.GetState(player, "Dashing") then
		dashinterput()
		return
	end
	if canplayer.CanDash(player) then 
		local dashdiraction = Rootpart.Position
		tackleevent:FireServer(dashdiraction) -- tells the server a dash started (with the player's position) so it can handle tackles
		humanoid.AutoRotate = false -- the character doesn't turn during the dash
		linearvelocity.VectorVelocity = direction
		linearvelocity.Enabled = true
		playerstats.SetState(player, "Dashing", true)
		running = false
		track:Play()
		track:AdjustSpeed(1.25)
		-- the dash ends when the animation reaches its "Contact" marker
		track:GetMarkerReachedSignal("Contact"):Once(function()
			dashend()
		end)
	end
end
-- each dash key and its direction and animation
local DASH_INPUTS = {
	[Enum.KeyCode.A] = {direction = Vector3.new(-100, 2, 0), track = ldashtrack},
	[Enum.KeyCode.D] = {direction = Vector3.new(100, 2, 0), track = Rdashtrack},
	[Enum.KeyCode.W] = {direction = Vector3.new(0, 2, -100), track = Fdashtrack},
	[Enum.KeyCode.S] = {direction = Vector3.new(0, 2, 100), track = Bdashtrack},
}
-- Q + a movement key = dash, not in the air or while running
-- if more than one movement key is held only the first match counts (A, D, W, S), which prevents conflicts
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	if input.KeyCode ~= Enum.KeyCode.Q then return end
	if inair or running then return end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		dash(DASH_INPUTS[Enum.KeyCode.A].direction, DASH_INPUTS[Enum.KeyCode.A].track)
	elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then
		dash(DASH_INPUTS[Enum.KeyCode.D].direction, DASH_INPUTS[Enum.KeyCode.D].track)
	elseif UserInputService:IsKeyDown(Enum.KeyCode.W) then
		dash(DASH_INPUTS[Enum.KeyCode.W].direction, DASH_INPUTS[Enum.KeyCode.W].track)
	elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
		dash(DASH_INPUTS[Enum.KeyCode.S].direction, DASH_INPUTS[Enum.KeyCode.S].track)
	end
end)


-- fired by the server when the ball hits this player (ifunbalanced = true) or when the player catches it (false)
-- causedby = what hit or threw the ball, duration = how long the knockback or catch lasts
velocityevent.OnClientEvent:Connect(function(causedby, ifunbalanced, duration)
	hitby = causedby
	print(hitby)
    playerstats.SetState(player, "Unbalance", ifunbalanced, 1)
	if not ifunbalanced then
		-- caught on the ground: the catch stance animation is replaced by the catch animation
		if not inair then
            playerstats.SetState(player, "Catching", true, duration)
			catchattempttrack:Stop()
			catchtrack:Play()
			print("Grounded catch")
		-- caught in the air: plays the air catch animation at 4x speed
		else
			print("arial catch")
			aircatchedtrack:Play()
			aircatchedtrack:AdjustSpeed(4)
			aircatchtrack:Stop()
			playerstats.SetState(player, "Catching", true, 0.25)
		end
		-- stops the catch animations once the catch is over
		task.delay(duration, function()
			aircatchedtrack:Stop()
			catchtrack:Stop()
		end)
	else
		-- got hit: hitby is cleared 0.6s after the knockback ends, until then handleImpact ignores it
		print(duration)
		task.delay(duration + 0.6 , function()
		hitby = nil
		end)
	end
end)
-- tap Q = dash (handled above), hold Q for 0.24s while moving = run
-- running starts at walkspeed 30 and speeds up by acc every 0.1s until runningspeed
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
if gameProcessedEvent then return end
	if input.KeyCode == Enum.KeyCode.Q then
		task.delay(0.24, function()
			if ismoving and UserInputService:IsKeyDown(Enum.KeyCode.Q) then
			    local sliding = playerstats.GetState(player, "Sliding")	
		        running = true
				humanoid.WalkSpeed = 30
				print("player is running")
				while running and ismoving and UserInputService:IsKeyDown(Enum.KeyCode.Q) and not sliding do
					task.wait(0.1)
					humanoid.WalkSpeed += acc
					currentspeed = humanoid.WalkSpeed
					if humanoid.WalkSpeed > runningspeed then
						humanoid.WalkSpeed = runningspeed
						currentspeed = humanoid.WalkSpeed
								print("Max Running Speed")		
								
					end
				end
			end
		end)
    end
end)
-- releasing Q slows the player down by deacc every 0.1s until they reach the base speed
UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	if input.KeyCode == Enum.KeyCode.Q then
		running = false
		while not running and not UserInputService:IsKeyDown(Enum.KeyCode.Q) do
			task.wait(0.1)
			if humanoid.WalkSpeed < baseSpeed then
				humanoid.WalkSpeed = baseSpeed
				currentspeed = humanoid.WalkSpeed
				print("Player is in walking state")
				break
			end
			humanoid.WalkSpeed -= deacc
			currentspeed = humanoid.WalkSpeed
		end
	end
end)

-- C key, what it does depends on the situation (checked in this order):
-- slide / stand up from a slide / crouch / knee tuck
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	if input.KeyCode == Enum.KeyCode.C then
		local kneetucked = playerstats.GetState(player, "KneeTucked")
		print("player is cansliding:".. tostring(canplayer.CanSlide(player)))
		print("player is moving: ".. tostring(ismoving))
		print("player is running: ".. tostring(running))
		-- SLIDE: needs to be allowed, moving, walkspeed above 30 (so running) and on the ground
		-- the slide isn't affected by gravity or slopes, it just loses speed over time
		if canplayer.CanSlide(player) and ismoving and humanoid.WalkSpeed > 30  and not inair then
			humanoid.AutoRotate = false
			linearvelocity.VectorVelocity = Vector3.new(0, 1, -currentspeed) -- pushes the player forward at the running speed
			linearvelocity.Enabled = true
			soundmanager.loopserver(slide, Rootpart, true)
			slidetrack:Play()
			slidetrack:AdjustSpeed(humanoid.WalkSpeed / 20) -- faster animation at higher speed
			print("slide")
			playerstats.SetState(player, "Sliding", true)
			currentspeed = humanoid.WalkSpeed
			if slidetrack.Ended then
				slidingtrack:Play() -- the looping slide animation
			end
			-- every 0.01s the slide loses 0.5 speed, the push follows currentspeed
			task.spawn(function()
				while playerstats.GetState(player, "Sliding") and currentspeed > 8 do
					task.wait(0.01)
					currentspeed -= 0.5
					humanoid.WalkSpeed = currentspeed
					linearvelocity.VectorVelocity = Vector3.new(0, 0.5, -currentspeed)
					print(currentspeed)
				end
				-- the slide ran out of speed (and wasn't already ended by the player): get up and give control back
				if currentspeed <= 8 and playerstats.GetState(player, "Sliding") then
					humanoid.WalkSpeed = baseSpeed
					linearvelocity.VectorVelocity = Vector3.new(0, 0, 0)
					slidingtrack:Stop()
					soundmanager.loopserver(slide.Name, Rootpart, false)
					getuptrack:Play()
					getuptrack.Ended:Wait()
					playerstats.SetState(player, "Sliding", false)
					humanoid.AutoRotate = true
					linearvelocity.Enabled = false
				end
			end)
		-- STAND UP: pressing C again during a slide ends it early, the get-up animation is faster at higher speed
		elseif playerstats.GetState(player, "Sliding") then
			getuptrack:Play()
			slidingtrack:Stop()
			soundmanager.loopserver(slide.Name, Rootpart, false)
			getuptrack:AdjustSpeed(humanoid.WalkSpeed / 9)
			linearvelocity.Enabled = false
			humanoid.AutoRotate = true
			playerstats.SetState(player, "Sliding", false)
		-- CROUCH: only when standing still on the ground, walkspeed drops to 8
		elseif not ismoving and not inair and not iscroching then
			iscroching = true
			humanoid.WalkSpeed = 8
			crouchitrack:Play()
			vaulttrack.Priority = Enum.AnimationPriority.Core -- lowers the vault animation's priority while crouched, set back when standing up
		-- KNEE TUCK: in the air, stays tucked until the humanoid's next state change (the landing)
		elseif inair and not playerstats.GetState(player, "Sliding") and not iscroching and not kneetucked then
			kneetucktrack:Play()
			playerstats.SetState(player, "KneeTucked", true)
			humanoid.StateChanged:Wait(Enum.HumanoidStateType.Landed)
			kneetucktrack:Stop()
			playerstats.RemoveStats(player, "KneeTucked")
		end
	end
end)

-- releasing C stands back up from a crouch
UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	if input.KeyCode == Enum.KeyCode.C then
		if iscroching then
			iscroching = false
			humanoid.WalkSpeed = baseSpeed
			crouchitrack:Stop()
			crouchmmtrack:Stop()
        	vaulttrack.Priority = Enum.AnimationPriority.Action3 -- back to the vault animation's normal priority
			humanoid.AutoRotate = true
		end
	end	
end)

-- kicks off a wall: plays the animation and launches the player away from the wall, a bit upward and forward
local function wallKick(track, awayFromWall)
	if not canplayer.CanWallKick(player) then return end
	track:Play()
	track:AdjustSpeed(2)
	soundmanager.EmitServer(jump, Rootpart)
	soundmanager.EmitServer(land, Rootpart)
	Rootpart.AssemblyLinearVelocity = (awayFromWall + Vector3.new(0, 0.75, 0) + Rootpart.CFrame.LookVector) * 75 + Vector3.new(Rootpart.AssemblyLinearVelocity)
end

-- pulls the player up onto the ledge they are hanging from
-- the "PullingUp" marker is the moment in the animation where the player is lifted
local function pullUpFromHang()
	Hangingtrack:Stop()
	pulluptrack:Play()
	soundmanager.EmitServer(jumpv, Rootpart)
	pulluptrack:AdjustSpeed(2.5)
	pulluptrack:GetMarkerReachedSignal("PullingUp"):Once(function()
		linearvelocity.Enabled = false
		Rootpart.AssemblyLinearVelocity = Vector3.new(0, 80, 0)
		playerstats.SetState(player, "Hanging", true, 0.1)
		humanoid.AutoRotate = true
	end)
end

-- grabs a ledge: snaps the player to it, then pulls up right away if the player isn't falling fast,
-- or hangs from the ledge if they are
-- rayroot = the ray that hit the wall in front of the player
local function ledgeGrab(rayroot, raycastparams)
	-- ray pointing down from 10 studs above the head at the wall's position, finds the top of the ledge
	local origin = Vector3.new(rayroot.Instance.Position.X, Head.Position.Y + 10, rayroot.Instance.Position.Z)
	local raysurface = workspace:Raycast(origin, Vector3.new(0, -20, 0), raycastparams)
	if not raysurface or not canplayer.CanHang(player) then return end -- no ledge top found, or hanging isn't allowed

	local playervelocity = Rootpart.AssemblyLinearVelocity -- saved now, decides pull up or hang below
	local hangdist = (Rootpart.Position - rayroot.Position).Magnitude - 1 -- distance to the wall, minus 1 so the player stops just short of it
	-- the position the player snaps to: 3 studs below the top of the ledge, moved forward by hangdist
	local Yoffsit = raysurface.Position * Vector3.new(0, 1, 0) - Vector3.new(0, 3, 0)
	local offsit = (Rootpart.CFrame.LookVector * hangdist * Vector3.new(1, 0, 1)) + (Rootpart.Position * Vector3.new(1, 0, 1)) + Yoffsit
	local lookAtPos = offsit - Vector3.new(rayroot.Normal.X, 0, rayroot.Normal.Z) -- a point into the wall so the player faces it

	tweenservice:Create(Rootpart, tweeninfo, {CFrame = CFrame.lookAt(offsit, lookAtPos)}):Play()
	playerstats.SetState(player, "Hanging", true)
	task.wait(0.05) -- waits for the snap tween to finish
	-- not falling fast: pulls straight up, the faster the player is moving upward the faster the animation plays
	if playervelocity.Y > -20 then
		pulluptrack:Play()
		Hangingtrack:Stop()
		soundmanager.EmitServer(jumpv, Rootpart)
		soundmanager.EmitServer(grab, Rootpart)
		pulluptrack:AdjustSpeed(playervelocity.Y / 10 + 5)
		pulluptrack:GetMarkerReachedSignal("PullingUp"):Once(function()
			Rootpart.AssemblyLinearVelocity = Vector3.new(0, 80, 0) + Vector3.new(Rootpart.AssemblyLinearVelocity)
			playerstats.SetState(player, "Hanging", false, 0.1)
			humanoid.AutoRotate = true
		end)
	-- falling fast: grabs the ledge and hangs, the LinearVelocity is enabled to hold the player in place
	else
		humanoid.AutoRotate = false
		ledgehangtrack:Play()
		soundmanager.EmitServer(grab, Rootpart)
		linearvelocity.Enabled = true
		ledgehangtrack.Stopped:Wait()
		-- after the grab animation, the hanging loop plays (unless the player already started pulling up)
		if playerstats.GetState(player, "Hanging") and not pulluptrack.IsPlaying then
			Hangingtrack:Play()
		end
	end
end

-- Space: pulls up if the player is hanging, otherwise in the air it checks for a ledge to grab or a wall to kick off
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent or input.KeyCode ~= Enum.KeyCode.Space then return end
	-- hanging: Space pulls up, unless the grab or pull up animation is still playing
	if playerstats.GetState(player, "Hanging") then
		if not ledgehangtrack.IsPlaying and not pulluptrack.IsPlaying then
			pullUpFromHang()
		end
		return
	end

	if not inair then return end

	-- the rays ignore the player's own body
	local raycastparams = RaycastParams.new()
	raycastparams.FilterDescendantsInstances = {character}
	raycastparams.FilterType = Enum.RaycastFilterType.Exclude

	-- 4 rays: a wall in front, a wall above the head in front (nothing there = it's a ledge), a wall on the right, a wall on the left
	local diraction = Rootpart.CFrame.LookVector * ledgegrabdistence
	local rayroot = workspace:Raycast(Rootpart.Position, diraction, raycastparams)
	local rayhead = workspace:Raycast(Head.Position + Vector3.new(0, 5, 0), diraction, raycastparams)
	local rightray = workspace:Raycast(Rootpart.Position, Rootpart.CFrame.RightVector * 3, raycastparams)
	local leftray = workspace:Raycast(Rootpart.Position, -Rootpart.CFrame.RightVector * 3, raycastparams)

	-- a wall in front with nothing above it and nothing on the sides = ledge
	if rayroot and not rayhead and not rightray and not leftray then
		ledgeGrab(rayroot, raycastparams)
	-- a wall only on one side = kick off it, away from the wall
	elseif rightray and not leftray then
		wallKick(rwallkicktrack, -Rootpart.CFrame.RightVector)
	elseif leftray and not rightray then
		wallKick(lwallkicktrack, Rootpart.CFrame.RightVector)
	end
end)

-- runs when a body part touches something while the player is dashing or unbalanced:
-- stops the player and plays a bump animation
local function handleImpact(hit)
if playerstats.GetState(player, "Bumbed") then return end -- already bumping, so it doesn't run twice
local dashing = playerstats.GetState(player, "Dashing")
local unbalance = playerstats.GetState(player, "Unbalance")
if not dashing and not unbalance then return end
    -- ignores the player's own body, balls, and whatever just hit the player
    if hit:IsDescendantOf(character) or hit:HasTag("Ball") then return end
   	if hitby and hit:IsDescendantOf(hitby) then return end
	-- freezes the player and marks them as bumped (dashend checks this so it doesn't end the dash too)
	playerstats.SetState(player, "Bumbed", true)
    playerstats.SetState(player, "Dashing", false)
    playerstats.SetState(player, "Unbalance", false)
    linearvelocity.VectorVelocity = Vector3.new(0, 0, 0)
    soundmanager.EmitServer(land, Rootpart)
	soundmanager.EmitServer(rubberImpact, Rootpart)
    print("Player has bumbed into".. tostring(hit))
    -- bumped into another player: tackle animation
    if hit.Parent:FindFirstChild("Humanoid") then
        Tackletrack:Play()
        Tackletrack:AdjustSpeed(4)
        Tackletrack.Ended:Wait()
    -- bumped into a wall: bump animation depending on where the wall is
    else
        -- the direction the player was moving, or facing if they weren't moving
        local moveDirection = Rootpart.AssemblyLinearVelocity.Magnitude > 0
            and Rootpart.AssemblyLinearVelocity.Unit
            or Rootpart.CFrame.LookVector

        -- ray that can only hit the touched part, to find the exact point of contact
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {hit}
        raycastParams.FilterType = Enum.RaycastFilterType.Include

        local result = workspace:Raycast(Rootpart.Position, moveDirection * 8, raycastParams)
        local contactPosition = result and result.Position or hit.Position -- falls back to the part's center if the ray missed

        -- dot products: how much the wall is in front/behind (frontDot) or to the right/left (rightDot) of the player
        local directionToWall = (contactPosition - Rootpart.Position).Unit
        local frontDot = Rootpart.CFrame.LookVector:Dot(directionToWall)
        local rightDot = Rootpart.CFrame.RightVector:Dot(directionToWall)

        -- whichever is bigger decides the animation: front/back or right/left
        local playedTrack
        if math.abs(frontDot) > math.abs(rightDot) then
            playedTrack = (frontDot > 0) and Fbumbtrack or Bbumptrack
        else
            playedTrack = (rightDot > 0) and Rbumptrack or Lbumptrack
        end
        playedTrack:Play()
        playedTrack.Ended:Wait()
    end
    -- bump is over: gives control back
    linearvelocity.Enabled = false
    playerstats.SetState(player, "Bumbed", false)
    humanoid.AutoRotate = true
    hitby = nil
end
-- the body parts that detect impacts
rarm.Touched:Connect(handleImpact)
larm.Touched:Connect(handleImpact)
torso.Touched:Connect(handleImpact)
Head.Touched:Connect(handleImpact)

if player.Character then
	setupHumanoid(player.Character)
end

player.CharacterAdded:Connect(setupHumanoid) -- sets up again after every respawn