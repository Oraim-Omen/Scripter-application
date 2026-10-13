--!optimize 2
local replicatedstorage = game:GetService("ReplicatedStorage")
local soundservice = game:GetService("SoundService")
local Players = game:GetService("Players")
local runservice = game:GetService("RunService")
local ts = game:GetService("TweenService")
local contentprovider = game:GetService("ContentProvider")

local soundmanager = require(replicatedstorage:WaitForChild("Scripts"):WaitForChild("SoundManager"))

--events
local events = replicatedstorage:WaitForChild("events")
local velocityevent = events:WaitForChild("VelocityEvent")
local catchevent = events:WaitForChild("Catchevent")
local animations = replicatedstorage:WaitForChild("Animations")
local directthrow = animations:WaitForChild("DirectThrow")
local overheadthrow = animations:WaitForChild("OverHeadThrow")
local rcurvethrow = animations:WaitForChild("RCurveThrow")
local lcurvethrow = animations:WaitForChild("LCurveThrow")

local ball = script.Parent
local chargingevent = ball.Events:WaitForChild("ChargingEvent")
local throwevent = ball.Events:WaitForChild("ThrowEvent")
local equipedevent = ball.Events:WaitForChild("EquipedEvent")

local handle = ball.Handle
local trail = handle.Trail
local fire = ball.Disk.Fire
local disk = ball.Disk
local diskglow = disk.PointLight
local maxcharge = handle.Maxcharge
--linearvelocity 
local balllinearvelocity = handle:WaitForChild("LinearVelocity")
contentprovider:PreloadAsync({directthrow, overheadthrow, rcurvethrow, lcurvethrow})
--config values
local catchduration = 0.25
local hitduration = 0.75

local Catchers = {}
local thrower = nil
local targethrp = nil
local didmaxcharge = false

local thrown = false
local homing = false
local charging = false

local charged = 0
local evaded = false
local isoverhead = false
local rightside = false
local leftside = false

-- ===== TUNING =====
local CHARGE_RATE = 100 
local DRAIN_RATE = 100    
local NORMAL_MAX = 100    -- normal charging stops here (must match the 100 in updatecolors)
local UPDATE_STEP = 0.03  -- seconds between refreshes of Charge.Value and colors

-- flight speed = (HOMING_SPEED_BASE + charge) / HOMING_SPEED_DIVIDE
local HOMING_SPEED_BASE = 75
local HOMING_SPEED_DIVIDE = 1.25   -- bigger = slower ball

-- curve shots
local CURVE_SIDE = 0.6             -- how hard left/right curve throws bend (bigger = wider curve)
local CURVE_UP = 0.025             -- small upward aim on every throw
local CURVE_OVERHEAD_UP = 0.6      -- extra upward aim for overhead throws
local MIN_CURVE_DISTANCE = 40      -- target closer than this at launch = no curve

-- Evade values
local EVADE_DISTANCE = 25          -- closer than this, a fast target can evade the ball
local EVADE_SPEED = 80             -- how fast the target must be moving to evade

-- catch and hit
local CATCH_ANGLE = 60             -- degrees off-center a catch still counts
local CATCH_WINDOW = 1.5           -- seconds the catch stance stays active
local CATCH_KNOCKBACK = 0.6        -- push when catching
local HIT_KNOCKBACK = 0.8          -- push when hit
local HIT_DAMAGE = 5             

-- throw animation speed = charge / THROW_ANIM_CHARGE + 1
local THROW_ANIM_CHARGE = 50       -- bigger = charge speeds up the throw animation less
-- ===== STATE (setPhase controls these, don't edit by hand) =====
local chargeFrom = 0
local chargeStart = 0
local chargeRate = 0
local chargeCap = NORMAL_MAX

local upOffset, side, speed
--Sounds
local ballsounds = soundservice.BallSounds

local ballimpact = ballsounds:WaitForChild("BallImpact")
local chargedup = ballsounds:WaitForChild("ChargedUp")
local throw = ballsounds:WaitForChild("Throw")

-- sets the disk, glow, fire and trail to one color
local function InstancesToUpdate(_, _,RGBColor)
	disk.Color = RGBColor
	diskglow.Color = RGBColor
	fire.Color = RGBColor
	trail.Color = ColorSequence.new(RGBColor)
end
-- updates the colors, glow and fire from the charge (blue above 100 = catch bonus)
-- the 2nd argument isn't used, it reads the `charging` variable instead
local function updatecolors(charge, _)
	charged = charge
	if charging then 
		if charged > 100 then
			InstancesToUpdate(charge, charging, Color3.fromRGB(0, 55, 255))
		else
			InstancesToUpdate(charge, charging, Color3.fromRGB(255, 0, 0))
		end
		diskglow.Range = ((charge/5.5) + 12)
		diskglow.Brightness = ((charge/40) + 0.5)
		fire.Enabled = true
		fire.Size = (charge/20)
		if charge >= 100 and not didmaxcharge then
			didmaxcharge = true
			maxcharge:Emit(1)
			soundmanager.play(chargedup, handle)
		end
	elseif charging == false then
		didmaxcharge = false
		diskglow.Range = ((charge/5.5) + 12)
		diskglow.Brightness = ((charge/40) + 0.5)
		fire.Size = (charge/20)
		if charge == 0 then
			print("serverdrained")
			disk.Color = Color3.fromRGB(255, 255,255)
			diskglow.Color = Color3.fromRGB(255, 255, 255)
			trail.Enabled = false
			fire.Enabled = false
			fire.Size = 2
		end
	end
end
-- resets the colors and the charge back to uncharged
local function normalcolors()
	chargeFrom = 0
	chargeStart = os.clock()
	chargeRate = 0
	charging = false
	ball.Charge.Value = 0

	disk.Color = Color3.fromRGB(255, 255, 255)
	diskglow.Color = Color3.fromRGB(255, 255, 255)
	diskglow.Range = 12
	diskglow.Brightness = 0.5
	trail.Enabled = false
	fire.Enabled = false
	fire.Size = 2
end

-- plays and stops each throw animation once so the first real throw doesn't lag
local function preloadanimations(hum)
	local directthrowtrack = hum:LoadAnimation(directthrow)
	local overheadthrowtrack = hum:LoadAnimation(overheadthrow)
	local rcurvethrowtrack = hum:LoadAnimation(rcurvethrow)
	local lcurvethrowtarck = hum:LoadAnimation(lcurvethrow)
	directthrowtrack:Play()
	overheadthrowtrack:Play()
	rcurvethrowtrack:Play()
	lcurvethrowtarck:Play()
	directthrowtrack:Stop()
	overheadthrowtrack:Stop()
	rcurvethrowtrack:Stop()
	lcurvethrowtarck:Stop()
end

-- resets the flags when the ball is equipped, massless so the ball doesn't weigh the player down
equipedevent.OnServerEvent:Connect(function(player)
local playercharacter = player.Character
local hum = playercharacter:WaitForChild("Humanoid")
preloadanimations(hum)
	thrown = false
	homing = false
	evaded = false
	handle.Massless = true
	disk.Massless = true
	handle.LinearVelocity.Enabled = false
end)

-- pushes a character away: in the air it adds speed,
-- on the ground it uses the LinearVelocity in their root part for a short time
local function applyKnockback(character, direction, duration)
	local rootPart = character.HumanoidRootPart
	local humanoid = character.Humanoid
	local state = humanoid:GetState()

	if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
		rootPart.AssemblyLinearVelocity += direction*2
	else
		local linearVelocity = rootPart.LinearVelocity
		linearVelocity.Enabled = true
		linearVelocity.VectorVelocity = direction

		task.delay(duration, function()
			linearVelocity.VectorVelocity = Vector3.zero
			linearVelocity.Enabled = false
		end)
	end
end

-- when the ball touches something: wall (miss), catch, or hit
handle.Touched:Connect(function(hit)
	if not thrown then return end
	if hit.Parent == thrower or hit.Name == "Handle" then return end
	if hit:IsDescendantOf(targethrp.Parent) and evaded then return end -- target dodged, ball passes through
	if targethrp.AssemblyLinearVelocity.Magnitude > EVADE_SPEED then return end
	print("nothoming")
	-- the ball is done flying, so physics control goes back to Roblox
	handle:SetNetworkOwnershipAuto()
	disk:SetNetworkOwnershipAuto()
	homing = false
	didmaxcharge = false
	handle.Massless = false
	disk.Massless = false
	thrown = nil
	handle.LinearVelocity.Enabled = false

	local character = hit.Parent
	local humanoid = character:FindFirstChild("Humanoid")

	-- no humanoid = hit a wall or floor
	if not humanoid then
		print("Missed!")
		normalcolors()
		soundmanager.play(ballimpact, hit)
		soundmanager.stoploop(ballsounds.Charging.Name, handle)
		-- the handle goes back inside the tool (ball), that's what lets the player pick it up and use it again
		handle.Parent = ball
		ball.Charge.Value = 0
		thrower = nil
		return
	end

	-- is the target facing the ball? both directions are flattened to the ground, then compared:
	-- 1 = looking straight at it, 0 = sideways, -1 = back turned. A bigger value than the cos of CATCH_ANGLE counts as facing
	local hrp = character.HumanoidRootPart
	local hrpXZ = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
	local handleXZ = Vector3.new(handle.Position.X, 0, handle.Position.Z)
	local dirToBall = (handleXZ - hrpXZ).Unit
	local lookXZ = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
	local alignment = dirToBall:Dot(lookXZ)
	local stancetime = Catchers[humanoid]
	local COS_MAX_ANGLE = math.cos(math.rad(CATCH_ANGLE))
	local targetPlayer = game.Players:GetPlayerFromCharacter(character)
	local ping = targetPlayer and targetPlayer:GetNetworkPing() or 0.1
	local grace = math.clamp(ping * 0.5, 0.03, 0.15) -- 30ms–150ms
	task.wait(grace) -- small wait based on ping so a laggy catch input can still arrive
	if stancetime and alignment >= COS_MAX_ANGLE then
		-- CATCH: in the stance and facing the ball
		local direction = balllinearvelocity.VectorVelocity * Vector3.new(1, 0, 1) * CATCH_KNOCKBACK
		local attachment0 = hrp:FindFirstChild("RootAttachment")
		local localDirection = attachment0.WorldCFrame:VectorToObjectSpace(direction)

		handle.Parent = ball
		disk.Parent = ball
		ball.Parent = humanoid.Parent
		applyKnockback(humanoid.Parent, localDirection, catchduration)
		velocityevent:FireClient(targetPlayer, thrower, false, catchduration)
		print(character.Name .. " has Catched the ball")

		-- the later into the stance the ball arrives, the less charge the catcher keeps
		local chargemultiplier = 1 - (workspace:GetServerTimeNow() - stancetime)
		ball.Charge.Value = charged * chargemultiplier
		updatecolors(ball.Charge.Value, true)
		soundmanager.play(ballimpact, hit)
	else -- HIT
		print("Target HIT!")
		local direction = balllinearvelocity.VectorVelocity * Vector3.new(1, 0, 1) * HIT_KNOCKBACK
		local attachment0 = hrp:FindFirstChild("RootAttachment")
		local localDirection = attachment0.WorldCFrame:VectorToObjectSpace(direction)

		humanoid.Health -= HIT_DAMAGE
		ball.Charge.Value = 0
		normalcolors()
		soundmanager.stoploop(ballsounds.Charging.Name, handle)
		soundmanager.play(ballimpact, handle)
		applyKnockback(humanoid.Parent, localDirection, hitduration)

		if targetPlayer then
			velocityevent:FireClient(targetPlayer, localDirection, true, hitduration)
		end

		if humanoid.Health == 0 then
			print(tostring(thrower) .. " has knockout " .. tostring(targetPlayer))
			local playerinstance = Players:GetPlayerFromCharacter(thrower)
			local leaderstats = playerinstance:FindFirstChild("leaderstats")
			leaderstats.Knockdowns.Value += 1
		end

		task.delay(0.5, function()
			handle.Parent = ball -- back into the tool
		end)
	end
	thrower = nil
end)

-- works out the curve and speed for this throw, the Heartbeat loop below uses them
local function SetCurve()
	upOffset = Vector3.new(0, CURVE_UP + (isoverhead and CURVE_OVERHEAD_UP or 0), 0)
	side = rightside and CURVE_SIDE or (leftside and -CURVE_SIDE or 0)
	speed = (HOMING_SPEED_BASE + charged) / HOMING_SPEED_DIVIDE
end

local startDistance

-- every frame while the ball is flying: steers it toward the target
runservice.Heartbeat:Connect(function()
	if not thrown or not homing then
		startDistance = nil
		return
	end

	local toTarget = targethrp.Position - handle.Position
	local distance = toTarget.Magnitude
	-- a fast target up close dodges the ball, it stops homing
	if distance < EVADE_DISTANCE and targethrp.AssemblyLinearVelocity.Magnitude > EVADE_SPEED then
		evaded = true
		homing = false
		return
	end

	startDistance = startDistance or distance

	local direction = toTarget.Unit
	-- fade goes from 1 at launch to 0 at the target, so the curve straightens out as the ball arrives
	local fade = startDistance > MIN_CURVE_DISTANCE and math.clamp(distance / startDistance, 0, 1) or 0
	local rightvector = direction:Cross(Vector3.yAxis).Unit
	local finaldireaction = (direction + (upOffset + rightvector * side) * fade).Unit

	handle.LinearVelocity.VectorVelocity = finaldireaction * speed
end)



-- The charge isn't added to every frame. It saves where the charge started (chargeFrom),
-- when (chargeStart) and how fast it changes (chargeRate), and works out the current value from that.
-- A "phase" is one stretch of time with one rate: charging up, draining down, or frozen.

-- current charge = starting charge + (rate * time passed), kept between 0 and chargeCap
local function getCharge()
	return math.clamp(chargeFrom + chargeRate * (os.clock() - chargeStart), 0, chargeCap)
end

-- Pushes the charge to everything that shows it:
-- ball.Charge.Value (other scripts read it) and updatecolors (glow, fire, colors)
local function refresh()
	local charge = math.floor(getCharge())
	ball.Charge.Value = charge
	updatecolors(ball.Charge.Value, charging)
	return charge
end

-- Starts a new phase. This is the only function you need to call yourself.
--   setPhase(CHARGE_RATE)   charge up from the current charge
--   setPhase(-DRAIN_RATE)   drain down from the current charge
--   setPhase(0)             freeze at the current charge
--   setPhase(0, 0)          freeze and reset to 0
-- `from` is optional, leave it out to continue from where the charge is now
local function setPhase(rate, from)
	chargeFrom = from or getCharge()
	chargeStart = os.clock()
	chargeRate = rate
	-- the cap is 100, unless we start above 100 (catch bonus), then we keep that charge
	chargeCap = math.max(NORMAL_MAX, chargeFrom)
	if rate > 0 then
		charging = true
		if chargeFrom < NORMAL_MAX then
			didmaxcharge = false  -- new charge below full: re-arm the full-charge effect
		end
	elseif rate < 0 then
		charging = false
	end
	refresh()
end

-- Keeps the visuals updating while charging or draining
task.spawn(function()
	while true do
		task.wait(UPDATE_STEP)
		if chargeRate ~= 0 then
			local charge = refresh()
			if chargeRate < 0 and charge <= 0 then  -- fully drained: stop
				setPhase(0)
			end
		end
	end
end)

-- "start" = player holds the charge key, "cancel" = they let go without throwing
chargingevent.OnServerEvent:Connect(function(_, action)
	if action == "start" then
		-- start from ball.Charge.Value so any bonus from the catch system is picked up
		setPhase(CHARGE_RATE, ball.Charge.Value)
		soundmanager.play(ballsounds.Charging, handle, true)
	elseif action == "cancel" then
		setPhase(-DRAIN_RATE)
		soundmanager.stoploop(ballsounds.Charging.Name, handle)
	end
end)

-- runs when the throw animation reaches the "Release" marker: the ball leaves the hand
local function ReleaseBall(AnimTrack)
	AnimTrack:GetMarkerReachedSignal("Release"):Once(function()
		local worldCFrame = handle.CFrame
		local tweenInfo = TweenInfo.new(0.01, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local handleTween = ts:Create(handle, tweenInfo, {CFrame = worldCFrame})
		SetCurve()
		setPhase(0)
		handleTween:Play()
		thrown = true
		homing = true	
		trail.Enabled = true
		-- first push toward the target, the Heartbeat loop takes over from the next frame
		handle.LinearVelocity.VectorVelocity = ((targethrp.Position - handle.Position).Unit + Vector3.new(0, 0.025, 0)) * (50 + charged/1.5)
		handle.LinearVelocity.Enabled = true	
		-- the tool leaves the player's character and the handle becomes a loose part in the workspace so it can fly
		ball.Parent = workspace
		handle.Parent = workspace
		-- network owner nil = the server controls the ball's physics, so the thrower can't affect it and it stays smooth
		handle:SetNetworkOwner(nil)
		disk:SetNetworkOwner(nil)
		soundmanager.play(throw, thrower)
	end)
end
-- runs when the animation reaches the "Recover" marker: back to normal speed, turns the thrower's LinearVelocity off
local function Recover(AnimTrack, hum)
	AnimTrack:GetMarkerReachedSignal("Recover"):Once(function()
		AnimTrack:AdjustSpeed(1)
		task.wait(0.5)
		hum.Parent.HumanoidRootPart.LinearVelocity.Enabled = false 
	end)
end
-- plays the throw animation (faster with more charge)
local function Throw(AnimTrack, hum)
	AnimTrack:Play()
	AnimTrack:AdjustSpeed(charged/THROW_ANIM_CHARGE + 1) 
	ReleaseBall(AnimTrack)
	Recover(AnimTrack, hum)
end
-- drop = nil or true: puts the ball down. Otherwise it's a throw with the throw type and target
throwevent.OnServerEvent:Connect(function(player, drop, overhead, rside, lside, target)
	local hum = player.Character:WaitForChild("Humanoid")
	thrower = player.Character
	if drop == nil or drop then
		local worldCFrame = handle.CFrame	
		ball.Parent = workspace.Balls
		handle.CFrame = worldCFrame
	elseif drop == false then
		if not target then return end
		local directthrowtrack = hum:LoadAnimation(directthrow)
		local overheadthrowtrack = hum:LoadAnimation(overheadthrow)
		local rcurvethrowtrack = hum:LoadAnimation(rcurvethrow)
		local lcurvethrowtarck = hum:LoadAnimation(lcurvethrow)
		rightside = rside
		leftside = lside
		isoverhead = overhead
		print(target)
		if target == nil then
			warn("no target")
		else
			print("target found")
			targethrp = target.HumanoidRootPart
		end
		charged = ball.Charge.Value
		hum.Parent.HumanoidRootPart.LinearVelocity.Enabled = true
		print("current charge value: "..tostring(charged)) 
		print("Overhead is"..tostring(overhead))
		print("Rside is"..tostring(rside)) 
		print("Lside is"..tostring(lside))
		if overhead == true then
			Throw(overheadthrowtrack, hum)
		elseif rside == true then
			Throw(rcurvethrowtrack, hum)
		elseif lside == true then
			Throw(lcurvethrowtarck, hum)
		else
			Throw(directthrowtrack, hum)
		end
	end
end)
-- saves when the player started the catch stance (sent by the client so ping doesn't matter), clears it after CATCH_WINDOW
catchevent.OnServerEvent:Connect(function(_, humanoid, stancetime) 
	Catchers[humanoid] = stancetime
	task.delay(CATCH_WINDOW, function()	
		Catchers[humanoid] = nil
	end)
end)