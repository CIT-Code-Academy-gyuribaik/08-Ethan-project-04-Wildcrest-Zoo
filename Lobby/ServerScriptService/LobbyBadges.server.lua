-- Roblox badges for the lobby
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local BADGES = {
	hired = 3106053235358477, -- "Hired!": joined the game
	founder = 2908874739469040, -- "Founder": joined while in beta test
}
-- lobby copies of the chapter badges: given when that chapter's achievement is unlocked
local CHAPTER_BADGES = {
	Ach_ch1 = 2087923174988948, -- Most Valuable Employee
	Ach_ch2 = 2852695493836821, -- Monster Hunter
	Ach_ch3 = 3889414947273725, -- Mission Impossible
	Ach_ch4 = 2703220673637410, -- Honoring Escape
}
local BETA = true -- set this to false when the game leaves beta (no more Founder badges after that)

local function give(p, id)
	local ok, has = pcall(function()
		return BadgeService:UserHasBadgeAsync(p.UserId, id)
	end)
	if ok and not has then
		pcall(function()
			BadgeService:AwardBadge(p.UserId, id)
		end)
	end
end
local function onJoin(p)
	p.AttributeChanged:Connect(function(attr)
		if CHAPTER_BADGES[attr] and p:GetAttribute(attr) == true then
			task.spawn(give, p, CHAPTER_BADGES[attr])
		end
	end)
	task.delay(5, function()
		if not p.Parent then
			return
		end
		give(p, BADGES.hired)
		if BETA then
			give(p, BADGES.founder)
		end
		for attr, id in CHAPTER_BADGES do
			if p:GetAttribute(attr) == true then
				give(p, id)
			end
		end
	end)
end
Players.PlayerAdded:Connect(onJoin)
for _, p in Players:GetPlayers() do
	onJoin(p)
end
