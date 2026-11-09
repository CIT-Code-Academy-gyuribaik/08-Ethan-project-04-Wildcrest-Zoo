-- Chapter 3: WILDCREST HQ - settings
local Config = {}
Config.EvidenceNeeded = 8
Config.EvidenceSpawned = 14        -- random loose files around the 3 floors (plus cabinets + the safe)
Config.IntroTime = 55          -- 40s intro + 15s sneaking in
Config.DifficultyChooseTime = 25
Config.ReturnToLobbyDelay = 32
Config.WalkSpeed, Config.SprintSpeed = 14, 23
Config.StaminaMax, Config.StaminaDrain, Config.StaminaRegen = 100, 15, 18
Config.StunRange = 20
Config.StunCooldown = 2
Config.StunMaxCharges = 6
Config.StunTime = { Guard = 9, B01 = 6, Marsh = 5 }
Config.CartridgeRespawn = 60
Config.BroadcastTime = 40          -- seconds of holding the roof console
Config.BroadcastRange = 18
Config.Monsters = {
	Guard = { PatrolSpeed = 7, ChaseSpeed = 14.5, Sight = 42, SightFlashlight = 58, FOV = 85, Hearing = 20, Sense = 5, CatchRange = 3.8,
		AgentRadius = 2, AgentHeight = 6, Anim = { idle = 656117400, walk = 656121766, run = 656118852 } },
	B01 = { PatrolSpeed = 8, ChaseSpeed = 16, Sight = 60, SightFlashlight = 80, FOV = 120, Hearing = 38, Sense = 7, CatchRange = 4.2,
		AgentRadius = 2.2, AgentHeight = 6.5, Anim = { idle = 616158929, walk = 616168032, run = 616163682 } },
	Marsh = { PatrolSpeed = 10, ChaseSpeed = 17.5, Sight = 75, SightFlashlight = 95, FOV = 110, Hearing = 45, Sense = 8, CatchRange = 4.5,
		AgentRadius = 2, AgentHeight = 6, Anim = { idle = 616136790, walk = 616146177, run = 616140816 } },
}
Config.DifficultyOrder = { "Easy", "Normal", "Hard", "Nightmare" }
Config.DefaultDifficulty = "Normal"
Config.Difficulties = {
	Easy = { Lives = 5, Speed = 0.82, Senses = 0.75, Stun = 1.4, StunCharges = 5, Guards = 1, Protect = 10, Color = Color3.fromRGB(110, 230, 120), Blurb = "5 lives. Slower hunters. Longer stuns." },
	Normal = { Lives = 3, Speed = 1, Senses = 1, Stun = 1, StunCharges = 4, Guards = 2, Protect = 7, Color = Color3.fromRGB(230, 220, 120), Blurb = "3 lives. The way it's meant to be played." },
	Hard = { Lives = 2, Speed = 1.12, Senses = 1.25, Stun = 0.8, StunCharges = 3, Guards = 4, Protect = 4, Color = Color3.fromRGB(240, 140, 60), Blurb = "2 lives. More guards, sharper senses." },
	Nightmare = { Lives = 1, Speed = 1.25, Senses = 1.5, Stun = 0.6, StunCharges = 2, Guards = 5, Protect = 2, Color = Color3.fromRGB(220, 40, 40), Blurb = "1 life. Good luck, employee." },
}
Config.Sounds = {
	Jumpscare = "rbxassetid://103702724347967",
	Heartbeat = "rbxassetid://9043365842",
	Alarm = "rbxassetid://9119661709",
	Growl = "rbxassetid://9114628818",
}
-- TOUGHER MONSTERS (user request 2026-11-09): faster, sharper eyes and ears
for _, m in Config.Monsters do
	m.PatrolSpeed *= 1.15
	m.ChaseSpeed *= 1.2
	m.Sight *= 1.3
	m.SightFlashlight *= 1.3
	m.Hearing *= 1.3
	m.Sense *= 1.25
	m.FOV = math.min(180, m.FOV + 15)
end
-- MORE LIVES (user request 2026-11-09)
for name, lives in { Easy = 10, Normal = 7, Hard = 5, Nightmare = 3 } do
	local d = Config.Difficulties[name]
	if d then
		d.Lives = lives
		d.Blurb = d.Blurb:gsub("^%d+ li[fv]es?%.", lives .. (lives == 1 and " life." or " lives."))
	end
end
-- CASH (banked in the lobby)
Config.CashBundles = 20
Config.CashPerBundle = 15
Config.FinishBonus = { Easy = 100, Normal = 200, Hard = 350, Nightmare = 500 }
Config.MaxEarnedPerRun = 2000
return Config
