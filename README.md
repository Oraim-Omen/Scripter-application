# Dodgeball Game: Scripts

The scripts for my 3v3 Roblox dodgeball game, written in Luau. This repo covers the movement system, the shared managers, and the ball (client and server).

**Demo:** [add your demo video link here]

## Script map

| Script | Runs on | What it does |
|---|---|---|
| Movement script | Client | Most of the player's movement: dash, running, slide, crouch, knee tuck, ledge grab and hang with pull-up, wall kick, and bump/tackle reactions. Mainly built around a LinearVelocity constraint. |
| PlayerStats | Shared (ReplicatedStorage/Scripts) | State manager. Keeps each player's states (Dashing, Sliding, Hanging, etc.). |
| CanPlayer | Shared (ReplicatedStorage/Scripts) | Holds the rules for what a player may do right now (CanDash, CanSlide, CanWallKick...). |
| CooldownManager | Shared (ReplicatedStorage/Scripts) | Charge-based cooldowns for abilities. |
| SoundManager | Shared (ReplicatedStorage/Scripts) | Plays and loops sounds, either locally or through the server so everyone hears them. |
| LocalBallScript | Client | The player's side of the ball: charging, uncharging, choosing the throw direction, and choosing a curve shot or not. |
| BallScript | Server | The ball itself: charge value, whether the ball curves, catchers, a few sounds, hit handling (damage and knockdowns), and the team values. |

## How a throw works

1. The player holds the throw button. LocalBallScript tells the server to start charging, and BallScript keeps the charge value and the ball's glow and fire up to date.
2. The player lets go. LocalBallScript sends the throw type (direct, overhead, left or right curve) and the target to BallScript.
3. BallScript plays the throw animation. When it reaches the "Release" marker, the ball leaves the hand with its first velocity.
4. Every frame while the ball flies, a Heartbeat loop steers it toward the target and bends it for curve shots.
5. When the ball touches something, BallScript decides if it is a miss, a catch (target was in the catch stance and facing the ball), or a hit.

## Structure

- Movement and ball scripts only talk to the shared managers through their functions (`GetState`, `SetState`, `CanDash`...), so each script stays readable on its own.
- The ball's physics run on the server, and the client only sends input.
