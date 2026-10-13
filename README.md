# Dodgeball Game Scripts

Scripts for my 3v3 Roblox dodgeball game, written in Luau. This covers the movement, the ball, and the managers they share.

The work examples aka scripts : Movement (client), localballscript and ballscript

Demos: [https://www.youtube.com/playlist?list=PLGGtIP81cKgg]

The game is still in development, so some of this will change.

## Scripts

| Script | Runs on | What it does |
|---|---|---|
| Movement script | Client | Most of the movement: dash, running, slide, crouch, knee tuck, ledge grab and hang, wall kick, and getting bumped. Dashes, slides and ledge hangs use a LinearVelocity constraint. |
| PlayerStats | Shared | Keeps track of what each player is doing (dashing, sliding, hanging...). |
| CanPlayer | Shared | Checks if a player is allowed to do something right now (CanDash, CanSlide...). |
| CooldownManager | Shared | Ability cooldowns, using charges. |
| SoundManager | Shared | Plays sounds, either locally or through the server so everyone hears them. |
| LocalBallScript | Client | Client side of the ball: charging, cancelling, picking the throw direction, and curve or not. |
| BallScript | Server | Server side of the ball: the charge value, curving, catchers, hits, a few sounds, and the team values. |

The shared scripts live in ReplicatedStorage/Scripts.

## How a throw works

1. Hold the throw button to charge. LocalBallScript tells the server, and BallScript keeps the charge (and the glow and fire) updated.
2. Let go. LocalBallScript sends the throw type (direct, overhead, left or right curve) and the target.
3. BallScript plays the throw animation, and when it reaches the Release marker the ball leaves the hand.
4. While the ball flies, a Heartbeat loop keeps aiming it at the target and bends it for curve shots.
5. When the ball touches something it's a miss (wall), a catch, or a hit. It counts as a catch if the target was in the catch stance and facing the ball.
