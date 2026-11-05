# Roblox Egg Throwing to Hatch a Pet Script

A Roblox script system for a "throw an egg to hatch a pet" game mechanic. Players throw eggs from a designated zone using a power meter with a sweet-spot timing mechanic, and eggs hatch into pets when they land on a designated pad.

## Install

1. In Roblox Studio, open your place.
2. In the Explorer, navigate to `ReplicatedStorage`.
3. Create a folder named `EggThrowRemotes` inside `ReplicatedStorage`.
4. Create a folder named `Pets` inside `ReplicatedStorage` and place any pet models (as Model or BasePart) inside it.
5. Create a folder named `Egg` inside `ReplicatedStorage` and place an egg model inside it.
6. In the Explorer, create a part named `HatchPad` in the workspace where eggs should hatch.
7. Create a part named `ThrowZone` in the workspace where players will stand to throw eggs.

## Use

1. Open the `ThrowZone.server.lua` script. Copy its contents into a new Script placed inside the `ThrowZone` part.
2. Open the `PowerMeter.client.lua` script. Copy its contents into a new LocalScript placed in `StarterPlayer > StarterPlayerScripts`.
3. Open the `EggHatch.server.lua` script. Copy its contents into a new Script placed in `ServerScriptService`.
4. Optionally, add a `SpawnPoint` part (BasePart) inside the `ThrowZone` to mark where eggs appear. If not added, one is created automatically.
5. Playtest. When a player walks into the throw zone, they receive an egg. A power meter appears on screen with a moving bar and a green sweet spot. Click or tap to stop the bar – hitting the green zone increases throw distance. The egg launches toward the hatch pad. When it lands on the pad, it hatches into a random pet from the Pets folder.
6. Tune the gameplay by editing the `CONFIG` tables at the top of each script: throw speed, sweet-spot size, hatch delay, etc.

---

More Roblox script projects by EnderDevelopment: https://github.com/EnderDevelopment

Project page: https://dash.enderdevelopment.com/community/17a26841-6554-4c33-bd1d-8416a2fc7a43?utm_source=github&utm_medium=readme&utm_campaign=auto_publish&utm_content=17a26841-6554-4c33-bd1d-8416a2fc7a43
