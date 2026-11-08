-- Tunable settings for Closing Time.
local Config = {}

-- Player movement
Config.WalkSpeed = 14
Config.SprintSpeed = 24
Config.CarryWalkSpeed = 12   -- while carrying the money
Config.CarrySprintSpeed = 20
Config.StaminaMax = 100
Config.StaminaDrain = 22     -- per second while sprinting
Config.StaminaRegen = 14     -- per second while not sprinting

-- Flashlight
Config.BatteryMax = 100
Config.BatteryDrain = 0.8    -- per second while on
Config.BatteryPickup = 45
Config.BatteryRespawn = 60   -- seconds before a taken battery comes back

Config.Lives = 3
-- Game pass: "Infinite Lives" (39 R$). Owners never lose lives when caught.
Config.InfiniteLivesPassId = 2076033249
-- Game pass: "Nokia Flashlight" (19 R$). Infinite flashlight battery.
Config.NokiaFlashlightPassId = 2074365358
Config.SafeCrackTime = 6     -- seconds to hold the safe prompt
Config.ReturnToLobbyDelay = 17 -- long enough for the van escape cutscene

-- Monsters. They get bigger as the night goes on:
--  Crawler (from the start), Stalker (after the keycard), Behemoth (after the money).
-- Sight = how far it can see you (0 = blind). SightFlashlight = with your light on.
-- Hearing = how far it hears you sprint (walking is heard at a quarter of that).
-- Sense = always notices you this close, even blind.
Config.Monsters = {
	Crawler = { PatrolSpeed = 9, ChaseSpeed = 18, Sight = 0, SightFlashlight = 0, FOV = 360, Hearing = 58, WalkHearing = 0.45, Sense = 9,
		CatchRange = 4.5, AgentRadius = 3, AgentHeight = 6, Color = Color3.fromRGB(190, 190, 185) },
	Stalker = { PatrolSpeed = 8, ChaseSpeed = 17.5, Sight = 55, SightFlashlight = 85, FOV = 80, Hearing = 26, Sense = 7,
		CatchRange = 4.5, AgentRadius = 2.5, AgentHeight = 10, Color = Color3.fromRGB(235, 235, 230) },
	Behemoth = { PatrolSpeed = 11, ChaseSpeed = 16, Sight = 80, SightFlashlight = 110, FOV = 100, Hearing = 45, Sense = 12,
		CatchRange = 8, AgentRadius = 5, AgentHeight = 16, Color = Color3.fromRGB(200, 40, 40) },
}
Config.ExtraCrawlersOnAlarm = 2

-- Unique abilities
Config.Abilities = {
	Crawler = { PounceRange = 13, PounceSpeed = 44, PounceTime = 0.45, PounceCooldown = 7 },
	Stalker = { InterferenceRange = 32, BatteryDrainMultiplier = 4, -- your flashlight fails near it; it's silent
		ScentRange = 16 }, -- SCENT: hiding doesn't work - it smells you inside lockers
	Behemoth = { ChargeMinRange = 12, ChargeMaxRange = 50, ChargeSpeed = 36, ChargeTime = 1.8, ChargeCooldown = 9, DazeTime = 1.6 },
}

-- Puzzles
Config.FusesNeeded = 3
Config.StunCharges = 3        -- charges the stun gun starts with
Config.StunMaxCharges = 4
Config.StunCooldown = 2.5     -- seconds between shots
Config.StunRange = 18
Config.StunTime = { Crawler = 10, Stalker = 9, Behemoth = 7 }
Config.CartridgeRespawn = 75
Config.RadarDuration = 8      -- seconds the radar highlights things
Config.RadarCooldown = 60     -- seconds before it can be used again (shared by the team)
Config.SamplesTotal = 6       -- REQUIRED to escape: 3 in the lab + one from each monster type

-- Free Creator Store sounds (swap any id you don't like).
Config.Sounds = {
	Jumpscare = "rbxassetid://103702724347967", -- "SCREAM MONSTER ROAR HORROR LOUD"
	Heartbeat = "rbxassetid://9043365842", -- APM "HEARTBEAT 02 96BPM"
	Alarm = "rbxassetid://9119661709", -- Pro Sound Effects submarine alarm
	Ambience = "rbxassetid://138890398994853", -- "Horror Cinematic Dark Scary Ambience"
}

-- Each monster growls now and then (3D sound, so you hear where it is),
-- and more often while chasing.
Config.MonsterSounds = {
	Crawler = { Id = "rbxassetid://73132281873037", Volume = 1.2, Pitch = 1.35, Range = 70 },
	Stalker = { Id = "rbxassetid://73132281873037", Volume = 1.3, Pitch = 0.8, Range = 80 },
	Behemoth = { Id = "rbxassetid://9114628818", Volume = 2.5, Pitch = 0.7, Range = 160 },
}

-- Difficulties (picked at the start of each round, at the gate)
Config.DifficultyOrder = { "Easy", "Normal", "Hard", "Nightmare" }
Config.DefaultDifficulty = "Normal"
Config.DifficultyChooseTime = 25
Config.IntroTime = 47 -- the Director's briefing cutscene (skippable) -- seconds before it defaults to Normal
Config.Difficulties = {
	Easy = { Lives = 5, Speed = 0.8, Senses = 0.75, Stun = 1.4, Battery = 0.6, StunCharges = 5, RadarCooldown = 40,
		StartCrawlers = 1, AlarmCrawlers = 1, Protect = 8, Color = Color3.fromRGB(110, 230, 120),
		Blurb = "5 lives. Slower, duller monsters. Longer stuns." },
	Normal = { Lives = 3, Speed = 1, Senses = 1, Stun = 1, Battery = 1, StunCharges = 3, RadarCooldown = 60,
		StartCrawlers = 1, AlarmCrawlers = 2, Protect = 5, Color = Color3.fromRGB(230, 220, 120),
		Blurb = "3 lives. The way it's meant to be played." },
	Hard = { Lives = 2, Speed = 1.15, Senses = 1.25, Stun = 0.8, Battery = 1.3, StunCharges = 3, RadarCooldown = 90,
		StartCrawlers = 2, AlarmCrawlers = 3, Protect = 4, Color = Color3.fromRGB(240, 140, 60),
		Blurb = "2 lives. Faster, sharper monsters. Two Crawlers from the start." },
	Nightmare = { Lives = 1, Speed = 1.3, Senses = 1.5, Stun = 0.6, Battery = 1.6, StunCharges = 2, RadarCooldown = nil,
		StartCrawlers = 2, AlarmCrawlers = 4, Protect = 2, Color = Color3.fromRGB(220, 40, 40),
		Blurb = "1 life. No radar. They see, hear and run like never before." },
}

-- Cash + shop (saved per player)
Config.EscapeReward = { Easy = 100, Normal = 250, Hard = 500, Nightmare = 1000 }
Config.SampleReward = 25 -- per sample secured, paid to everyone who escapes
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

return Config
