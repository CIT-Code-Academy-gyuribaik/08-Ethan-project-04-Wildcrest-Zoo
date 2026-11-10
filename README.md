# 08-Ethan-project-04-Wildcrest-Zoo

**Closing Time** – a Roblox horror game in chapters. Wildcrest Corp. runs a zoo, a mall,
an HQ... and an experiment program it really doesn't want anyone to find out about.

This repo is a backup of the game's **scripts** (the maps and models live in the Roblox
places themselves).

| Folder | Roblox place | What happens |
| --- | --- | --- |
| `Lobby/` | Wildcrest Zoo (lobby) – 108931139177949 | Night parking lot. Pick a chapter by getting in its van. |
| `Chapter1-ClosingTime/` | Game – 83038203301781 | Abandoned zoo: grab the money from the safe, escape the monsters. |
| `Chapter2-LastCall/` | Chapter 2 – 111676436621322 | Abandoned mall: capture B-00, then survive the boss fight. |
| `Chapter3-WildcrestHQ/` | Chapter 3 – 79977116634672 | Wildcrest HQ: collect evidence and try to expose them. |
| `Chapter4-LastStop/` | Chapter 4 – 92821442354468 | Wildcrest raids your apartment; escape through the subway. |

## Chapter 4: Last Stop (7 parts)

1. **The Raid** – escape your apartment tower (balcony ledge, stairs, elevator shaft, lobby).
2. **Old Town Station** – station key, the service gate, the figure on the tracks, the live rail.
3. **The Dark Tunnel** – runaway trains (hide in the alcoves) and the thing on the ceiling.
4. **Construction Station** – generator, lift, walkway over the collapse, sewer hatch.
5. **The Sewers** – knee-deep water, close 3 valves to open the gate.
6. **Control Center** – switch the tracks and restore power while Marsh hunts you.
7. **Last Stop** – the last train, the chase car to car, uncouple, the island map.

Chapter 5 (the island) is the finale – coming next.

## Cash and the lobby shop

- Every chapter pays out cash (bundles to find + a finish bonus by difficulty). When the van
  takes you back, the chapter sends what you **earned** on that run; the lobby banks it
  (max $2,000 per run).
- Spend it at the **Black Market Supplies** stall in the lobby: flashlight upgrades, flashlight
  beam colours, outfits (SWAT Agent, Director's Suit, Lost Guest), skills (Sprinter, Silent
  Steps, Sixth Sense, Stun Battery, Extra Life) and **Spare Lives** ($75, up to 5, used up on
  your next run).
- The van carries your purchases into the chapter (`UpgradesByUser` in the teleport data).
- The **Infinite Lives** game pass works in every chapter.
- Every place plays in **first person** (press **M** to free the mouse).

## New players and parties

- **Tutorial:** the lobby opens a 6-page "How to play" guide the first time you join (and a
  **HOW TO PLAY** button any time). Arrows and a dotted path point to the vans and the shop.
  Every chapter shows a controls card when you start.
- **Own server per party:** everyone in the same van gets their own private server of the
  chapter. The lobby sends a `PartyId`; each chapter's `PartyRouter` groups the party on
  arrival, reserves a server and moves them there (only works in the published game).

## Secret endings

Every chapter hides a glowing **???** item (purple sparkles). If anyone in the party picks it up
and you win, a secret cutscene plays after the normal ending: the Director in his monitoring
room, then a map of the island (a tease for Chapter 5). +$150, and the lobby tracks
**SECRET ENDINGS x/4** (`SecretEnding.server.lua` + `SecretEndingClient.client.lua` in each chapter).

## Achievements, badges and more

- **32 achievements** (lobby `AchievementList`): beat chapters, harder difficulties, no-catch and speed runs,
  party size, secret endings, shop collections. Each pays cash; chapters send run stats (`RunStats`) to the lobby.
- **Roblox badges:** Hired! and Founder in the lobby, a "beat it" and a "beat it on Nightmare" badge in every
  chapter (plus lobby copies of the chapter badges, given from the achievements).
- **Daily reward** ($50, up to $200 for a 7-day streak) and a **FASTEST ESCAPES** board in the lobby (OrderedDataStores).
- **Settings** (press **O**): brightness, mouse sensitivity, volume. Saved in the lobby and carried into chapters.
- **Phone buttons** in every chapter (Ch 3 and 4 route them through the keyboard handlers).
- Joining a chapter directly (not from a lobby van) sends you to the lobby first.

## Script layout

Paths mirror where each script lives in Roblox Studio:

- `*.server.lua` – Script (server)
- `*.client.lua` – LocalScript
- `*.lua` – ModuleScript
