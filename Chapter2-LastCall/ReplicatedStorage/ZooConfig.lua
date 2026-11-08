-- Tunable settings for Closing Time - Chapter 2: Last Call (the mall).
local Config = {}
Config.Chapter = 2

-- Player movement
Config.WalkSpeed = 14
Config.SprintSpeed = 24
Config.CarryWalkSpeed = 13   -- while carrying the bait
Config.CarrySprintSpeed = 22
Config.StaminaMax = 100
Config.StaminaDrain = 22
Config.StaminaRegen = 14

-- Flashlight
Config.BatteryMax = 100
Config.BatteryDrain = 0.8
Config.BatteryPickup = 45
Config.BatteryRespawn = 60

Config.Lives = 3
-- Game passes (Chapter 1's passes, checked by id)
Config.InfiniteLivesPassId = 2076033249
Config.NokiaFlashlightPassId = 2074365358
Config.ReturnToLobbyDelay = 16 -- ending cutscene (8.5s) + results screen

-- Monsters
Config.Monsters = {
	Crawler = { PatrolSpeed = 9, ChaseSpeed = 18, Sight = 0, SightFlashlight = 0, FOV = 360, Hearing = 58, WalkHearing = 0.45, Sense = 9,
		CatchRange = 4.5, AgentRadius = 3, AgentHeight = 6, Color = Color3.fromRGB(190, 190, 185) },
	Behemoth = { PatrolSpeed = 13, ChaseSpeed = 19, Sight = 95, SightFlashlight = 125, FOV = 110, Hearing = 55, Sense = 14,
		CatchRange = 8, AgentRadius = 4.5, AgentHeight = 15, Color = Color3.fromRGB(200, 40, 40) },
}
Config.Abilities = {
	Crawler = { PounceRange = 13, PounceSpeed = 44, PounceTime = 0.45, PounceCooldown = 7 },
	Behemoth = { ChargeMinRange = 12, ChargeMaxRange = 55, ChargeSpeed = 40, ChargeTime = 1.8, ChargeCooldown = 7, DazeTime = 1.4,
		RoarCooldown = 25, RoarRange = 90, SlamRange = 12, SlamRadius = 20, SlamCooldown = 10, SlamSlowTime = 2.5 },
}
-- Only the Behemoth in this chapter.
Config.ClampHoldTime = 2.5    -- hold to lock each cage clamp
Config.ThrashMin, Config.ThrashMax = 5, 7.5 -- seconds between its slams while trapped
Config.ThrashRange = 22      -- slams knock you off the clamps within this distance of the cage
Config.RadioHoldTime = 3     -- hold to call the pickup
-- Player abilities
Config.FlaresPerRound = 2  -- [G] throw a flare: the Behemoth goes to stare at it
Config.FlareTime = 10
Config.FlareRange = 140
Config.DashCooldown = 8    -- [C] quick dash
Config.DashStamina = 25

-- Capture
Config.FusesNeeded = 3
Config.BaitEatTime = 18      -- seconds the Behemoth stays at the bait
Config.WinchReset = 30       -- seconds before the cage can be tried again after a miss

-- Stun gun
Config.StunCharges = 3
Config.StunMaxCharges = 4
Config.StunCooldown = 2.5
Config.StunRange = 18
Config.StunTime = { Crawler = 10, Behemoth = 11 }
Config.CartridgeRespawn = 75
Config.RadarDuration = 8
Config.RadarCooldown = 60

Config.Sounds = {
	Jumpscare = "rbxassetid://103702724347967",
	Heartbeat = "rbxassetid://9043365842",
	Alarm = "rbxassetid://9119661709",
	Ambience = "rbxassetid://138890398994853",
}
Config.MonsterSounds = {
	Crawler = { Id = "rbxassetid://73132281873037", Volume = 1.2, Pitch = 1.35, Range = 70 },
	Behemoth = { Id = "rbxassetid://9114628818", Volume = 2.5, Pitch = 0.7, Range = 160 },
}

-- Difficulties
Config.DifficultyOrder = { "Easy", "Normal", "Hard", "Nightmare" }
Config.DefaultDifficulty = "Normal"
Config.DifficultyChooseTime = 25
Config.IntroTime = 50 -- the opening cutscene (skippable)
Config.Difficulties = {
	Easy = { Lives = 5, Speed = 0.8, Senses = 0.75, Stun = 1.4, Battery = 0.6, StunCharges = 5, RadarCooldown = 40,
		StartCrawlers = 1, AlarmCrawlers = 2, Protect = 8, Color = Color3.fromRGB(110, 230, 120), Blurb = "5 lives. Slower, duller monsters. Longer stuns." },
	Normal = { Lives = 3, Speed = 1, Senses = 1, Stun = 1, Battery = 1, StunCharges = 3, RadarCooldown = 60,
		StartCrawlers = 2, AlarmCrawlers = 3, Protect = 5, Color = Color3.fromRGB(230, 220, 120), Blurb = "3 lives. The way it's meant to be played." },
	Hard = { Lives = 2, Speed = 1.15, Senses = 1.25, Stun = 0.8, Battery = 1.3, StunCharges = 3, RadarCooldown = 90,
		StartCrawlers = 2, AlarmCrawlers = 4, Protect = 4, Color = Color3.fromRGB(240, 140, 60), Blurb = "2 lives. Faster, sharper monsters." },
	Nightmare = { Lives = 1, Speed = 1.3, Senses = 1.5, Stun = 0.6, Battery = 1.6, StunCharges = 2, RadarCooldown = nil,
		StartCrawlers = 3, AlarmCrawlers = 5, Protect = 2, Color = Color3.fromRGB(220, 40, 40), Blurb = "1 life. No radar. Good luck." },
}

-- Cash + shop (saved per player in this place)
Config.EscapeReward = { Easy = 150, Normal = 350, Hard = 700, Nightmare = 1400 }
Config.CashPickupMin, Config.CashPickupMax = 10, 40
Config.Shop = {
	{ Id = "Flashlight", Name = "Flashlight", Tiers = {
		{ Name = "Old Flashlight", Price = 0, Range = 60, Brightness = 3.5, Angle = 50, Drain = 1 },
		{ Name = "Bright Beam", Price = 300, Range = 75, Brightness = 4, Angle = 52, Drain = 0.85, Text = "Longer beam, drains 15% slower" },
		{ Name = "Tactical Light", Price = 900, Range = 90, Brightness = 4.8, Angle = 56, Drain = 0.65, Text = "Much brighter, drains 35% slower" },
		{ Name = "Floodlight", Price = 2500, Range = 110, Brightness = 5.5, Angle = 62, Drain = 0.45, Text = "Widest + brightest, drains 55% slower" },
	} },
	{ Id = "Shoes", Name = "Shoes", Tiers = {
		{ Name = "Work Boots", Price = 0, Stamina = 1 },
		{ Name = "Running Shoes", Price = 500, Stamina = 1.35, Text = "Sprint 35% longer" },
		{ Name = "Pro Sneakers", Price = 1500, Stamina = 1.7, Text = "Sprint 70% longer" },
	} },
	{ Id = "Stun", Name = "Stun Gun", Tiers = {
		{ Name = "Standard Stun Gun", Price = 0, Bonus = 0 },
		{ Name = "Extra Cell", Price = 600, Bonus = 1, Text = "+1 starting stun charge" },
		{ Name = "Overcharged", Price = 1800, Bonus = 2, Text = "+2 starting stun charges" },
	} },
}
function Config.ShopTier(id, tier)
	for _, item in Config.Shop do
		if item.Id == id then
			return item.Tiers[math.clamp(tier or 1, 1, #item.Tiers)], item
		end
	end
end

-- Finale
Config.ChokeTime = 9        -- seconds before you black out
Config.ChokePerPress = 7    -- break-free progress per press
Config.ChokeDecay = 15      -- progress lost per second (rises over time)
Config.BossHP = 75
Config.BossHPScale = { Easy = 0.7, Normal = 1, Hard = 1.25, Nightmare = 1.5 }
Config.SyringeDamage = 30   -- inject while it's stunned
Config.FuelDamage = 35      -- flare into the fuel puddle while it's in it
Config.FlareDamage = 10     -- flare thrown right at it
Config.FuelRefill = 25
Config.WreckRespawn = 12
Config.MaxSyringes = 2
Config.BossDazeTime = 5
Config.BehemothScale = 0.7  -- how big B-00 is (1 = original size)
Config.BossSpeed = 0.82      -- B-00 is slower in the small crash-site arena
Config.BossStunCharges = 6   -- stun shots you get for the boss fight
Config.BossSyringes = 2      -- syringes you start the boss fight with
Config.EarlyCrawlers = { Easy = 0, Normal = 0, Hard = 0, Nightmare = 0 } -- prowling from the start
Config.NoCrawlers = true -- Chapter 2 is just you and B-00
Config.EnrageCrawlers = { Easy = 0, Normal = 0, Hard = 0, Nightmare = 0 } -- join the fight at half HP -- dodge its charge into the wreck/trees

return Config
