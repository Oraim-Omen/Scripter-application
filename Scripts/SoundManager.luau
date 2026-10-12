local RunService = game:GetService("RunService") -- used to check if this code is running on the server or the client
local debris = game:GetService("Debris") -- used to clean up sounds after they finish
local replicatedstorage = game:GetService("ReplicatedStorage") -- where the remote events are stored

-- remote event used to play a one-shot sound for every player
local emitsound = replicatedstorage:WaitForChild("events"):WaitForChild("EmitSound")
-- remote event used to play a looping sound for every player
local loopsoundevent = replicatedstorage:WaitForChild("events"):WaitForChild("LoopSound")

local sound = {} -- the module table, everything inside it can be used by other scripts

-- function to randomize the pitch of a sound object to add variety to the sound effects
local function soundspeed(soundobj) -- takes a sound object as an argument
	local base = soundobj:GetAttribute("BaseSpeed") -- checks if the original speed was already saved on this sound
	if not base then
		base = soundobj.PlaybackSpeed -- takes the current playback speed for sounds that aren't playbackspeed 1
		soundobj:SetAttribute("BaseSpeed", base) -- sets the base speed for the sound object so it can be used for future calls to this function
	end

	local randompitch = math.random(9, 11) / 10 -- randomly generates a pitch value between 0.9 and 1.1
	soundobj.PlaybackSpeed = base * randompitch -- sets the playback speed
end

-- main function to play sounds either by a loop or a part
function sound.play(name, part, loop) -- name = the sound object, part = where it plays from, loop = true to keep it playing
	if not name then return end -- stops if no sound was given
	local soundobj = name:Clone() -- clone so the same sound can be played multiple times at once
	if not part then
		soundobj.Parent = workspace -- if no part is provided, the sound will be played in the workspace
	else
		soundobj.Parent = part -- the part the sounds will be played from
	end
	soundspeed(soundobj) -- sets random pitch
	if not soundobj.IsLoaded then  -- just a check to make sure the sound is loaded
		soundobj.Loaded:Wait() -- waits until the sound has finished loading
	end
	soundobj:Play() -- plays the sound
	if loop then return end -- if loop is true, the sound will loop and not be deleted
	debris:AddItem(soundobj, soundobj.TimeLength / soundobj.PlaybackSpeed) -- deletes the sound once it finishes (length divided by speed since the pitch changes how long it takes)
end

-- function to stop a looped sound by name and part, it will remove the sound object from the part
function sound.stoploop(name, part)
	local soundobj = part:FindFirstChild(name) -- finds the sound object by name in the part
 	debris:AddItem(soundobj, 0) -- removes the sound object from the part immediately
end	

-- function to start or stop a looping sound for everyone, called from a client
function sound.loopserver(name, part, loop)
	if not name then return end -- stops if no sound was given
	if not loop then
		sound.stoploop(name, part) -- if loop is false, stop the loop on this client right away
	end
	loopsoundevent:FireServer(name, part, loop) -- tells the server so it can pass it on to everyone else
end	

-- function to play a one-shot sound for everyone, called from a client
function sound.EmitServer(name, part, loop)
	if not name then return end -- stops if no sound was given
	emitsound:FireServer(name, part, loop) -- sends the sound info to the server
end

-- server side: receives the request from a client and sends it to every client
if RunService:IsServer() then
	emitsound.OnServerEvent:Connect(function(_, name, part, loop) -- the first argument is the player who fired it, not needed here
		emitsound:FireAllClients(name, part, loop) -- makes every client play the sound
	end)
else
	emitsound.OnClientEvent:Connect(sound.play) -- client side: when the server says so, play the sound
end

-- same idea as above but for looping sounds
if RunService:IsServer() then
	loopsoundevent.OnServerEvent:Connect(function(_, name, part, loop)
		if not loop then return end -- the server only passes on loops that are starting, not stopping
		loopsoundevent:FireAllClients(name, part, loop) -- makes every client start the looping sound
	end)
else
	loopsoundevent.OnClientEvent:Connect(sound.play) -- client side: when the server says so, play the looping sound
end

return sound -- gives the module table to whatever script requires it