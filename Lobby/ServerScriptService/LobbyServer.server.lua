-- Lobby: one van per chapter. Step into the zone behind a van to queue; when
-- the countdown ends, everyone in that zone rides to that chapter together.
-- Chapter 2 unlocks once you've escaped Chapter 1 (saved per player).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local PlaceIds = require(ReplicatedStorage:WaitForChild("PlaceIds"))
local COUNTDOWN = 15 -- seconds after the first player joins a van
local MAX_PLAYERS = 6

local lobby = workspace:WaitForChild("Lobby")
local VANS = {
	{ model = lobby:WaitForChild("Van"), chapter = 1, place = "Game", requires = nil, name = "Chapter 1" },
	{ model = lobby:WaitForChild("Van2"), chapter = 2, place = "Chapter2", requires = 1, name = "Chapter 2" },
	{ model = lobby:WaitForChild("Van3"), chapter = 3, place = "Chapter3", requires = 2, name = "Chapter 3" },
	{ model = lobby:WaitForChild("Van4"), chapter = 4, place = "Chapter4", requires = 3, name = "Chapter 4" },
}

local remotes = ReplicatedStorage:FindFirstChild("LobbyRemotes") or Instance.new("Folder")
remotes.Name = "LobbyRemotes"
remotes.Parent = ReplicatedStorage
local function remote(name)
	local r = remotes:FindFirstChild(name) or Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local Departing = remote("Departing")
local Notify = remote("Notify")

-- Progress (which chapters you've beaten) ----------------------------------------
local store
pcall(function()
	store = DataStoreService:GetDataStore("LobbyProgress_v1")
end)
local progress = {} -- [player] = { Completed = { [1] = true, ... }, Cash, Owned, Equip }
local shopSync
local function save(player)
	local prof = progress[player]
	if store and prof and prof.loaded then
		pcall(function()
			store:SetAsync("p_" .. player.UserId, { Completed = prof.Completed, Cash = prof.Cash, Owned = prof.Owned, Equip = prof.Equip, Spare = prof.Spare, Secrets = prof.Secrets, Ach = prof.Ach, Wins = prof.Wins, Spent = prof.Spent, Best = prof.Best, Settings = prof.Settings, LastDay = prof.LastDay, Streak = prof.Streak, BestTime = prof.BestTime })
		end)
	end
end
local function hasBeaten(player, chapter)
	-- The game's creator can ride every van (for testing).
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	local prof = progress[player]
	return prof ~= nil and prof.Completed[tostring(chapter)] == true
end
local function refreshUnlock(player)
	player:SetAttribute("Ch2Unlocked", hasBeaten(player, 1))
	player:SetAttribute("Ch3Unlocked", hasBeaten(player, 2))
	player:SetAttribute("Ch4Unlocked", hasBeaten(player, 3))
end
-- ACHIEVEMENTS ---------------------------------------------------------------------------
local AchList = require(ReplicatedStorage:WaitForChild("AchievementList"))
local achById = {}
for _, a in AchList do
	achById[a.id] = a
end
local AchRemote = remote("Achievement")
local function achSync(player)
	local prof = progress[player]
	if not prof then
		return
	end
	for _, a in AchList do
		player:SetAttribute("Ach_" .. a.id, prof.Ach[a.id] == true)
	end
end
local function grant(player, id)
	local prof = progress[player]
	local a = achById[id]
	if not prof or not prof.loaded or not a or prof.Ach[id] then
		return
	end
	prof.Ach[id] = true
	prof.Cash += a.reward
	save(player)
	if shopSync then
		shopSync(player)
	end
	achSync(player)
	AchRemote:FireClient(player, id)
	if prof.Cash >= 5000 then
		grant(player, "rich")
	end
	local count = 0
	for _ in prof.Ach do
		count += 1
	end
	if count >= 15 then
		grant(player, "hunter")
	end
end
local function shopAch(player)
	local prof = progress[player]
	if not prof then
		return
	end
	local o = prof.Owned
	if (prof.Spent or 0) > 0 or next(o) ~= nil then
		grant(player, "shopper")
	end
	if (prof.Spent or 0) >= 2000 then
		grant(player, "bigspender")
	end
	if o.flash2 then
		grant(player, "maxpower")
	end
	if o.beam_ice and o.beam_uv and o.beam_red then
		grant(player, "lightshow")
	end
	if o.skin_agent and o.skin_director and o.skin_guest then
		grant(player, "fashion")
	end
	if o.sprinter and o.silent and o.sixth and o.stun and o.life then
		grant(player, "loaded")
	end
	if (prof.Spare or 0) >= 5 then
		grant(player, "stocked")
	end
	if prof.Cash >= 5000 then
		grant(player, "rich")
	end
end
-- SETTINGS + DAILY REWARD ----------------------------------------------------------------
local SettingsRemote = remote("Settings")
local DailyRemote = remote("Daily")
local function settingsSync(player)
	local prof = progress[player]
	if not prof then
		return
	end
	for _, k in { "Bright", "Sens", "Vol" } do
		player:SetAttribute("Set_" .. k, prof.Settings[k])
	end
end
SettingsRemote.OnServerEvent:Connect(function(player, key, value)
	local prof = progress[player]
	if not prof or (key ~= "Bright" and key ~= "Sens" and key ~= "Vol") or type(value) ~= "number" then
		return
	end
	prof.Settings[key] = math.clamp(math.floor(value), 0, 10)
	prof.settingsDirty = true
	settingsSync(player)
end)
task.spawn(function()
	while true do
		task.wait(30)
		for p, prof in progress do
			if prof.settingsDirty then
				prof.settingsDirty = nil
				save(p)
			end
		end
	end
end)
-- SHOP ---------------------------------------------------------------------------------
local Catalog = require(ReplicatedStorage:WaitForChild("ShopCatalog"))
local byId = {}
for _, item in Catalog do
	byId[item.id] = item
end
shopSync = function(player)
	local prof = progress[player]
	if not prof then
		return
	end
	player:SetAttribute("Cash", prof.Cash)
	player:SetAttribute("Spare", prof.Spare or 0)
	for _, item in Catalog do
		player:SetAttribute("Own_" .. item.id, prof.Owned[item.id] == true)
	end
	player:SetAttribute("Eq_flashSkin", prof.Equip.flashSkin or "")
	player:SetAttribute("Eq_skin", prof.Equip.skin or "")
end
local function upgradesFor(player)
	local prof = progress[player]
	if not prof then
		return {}
	end
	local o = prof.Owned
	return {
		flash = (o.flash2 and 2) or (o.flash1 and 1) or 0,
		flashSkin = prof.Equip.flashSkin or "",
		skin = prof.Equip.skin or "",
		sprinter = o.sprinter == true,
		silent = o.silent == true,
		sixth = o.sixth == true,
		stunPlus = o.stun and 1 or 0,
		extraLife = (o.life and 1 or 0) + (prof.Spare or 0),
		settings = prof.Settings,
	}
end
local ShopRF = remotes:FindFirstChild("Shop") or Instance.new("RemoteFunction")
ShopRF.Name = "Shop"
ShopRF.Parent = remotes
ShopRF.OnServerInvoke = function(player, action, id)
	local prof = progress[player]
	local item = type(id) == "string" and byId[id]
	if not prof or not prof.loaded or not item then
		return false, "Shop is not ready yet."
	end
	if action == "buy" and item.consumable then
		if (prof.Spare or 0) >= (item.max or 5) then
			return false, ("You can only hold %d."):format(item.max or 5)
		end
		if prof.Cash < item.price then
			return false, ("Not enough cash (need $%d)."):format(item.price)
		end
		prof.Cash -= item.price
		prof.Spare = (prof.Spare or 0) + 1
		prof.Spent = (prof.Spent or 0) + item.price
		task.defer(shopAch, player)
		save(player)
		shopSync(player)
		return true, ("Bought a Spare Life! You have %d for your next run."):format(prof.Spare)
	end
	if action == "buy" then
		if prof.Owned[id] then
			return false, "You already own that."
		end
		if item.requires and not prof.Owned[item.requires] then
			return false, "Buy " .. byId[item.requires].name .. " first."
		end
		if prof.Cash < item.price then
			return false, ("Not enough cash (need $%d)."):format(item.price)
		end
		prof.Cash -= item.price
		prof.Owned[id] = true
		prof.Spent = (prof.Spent or 0) + item.price
		task.defer(shopAch, player)
		if item.slot == "skin" then
			task.defer(grant, player, "dressed")
		end
		if item.slot then
			prof.Equip[item.slot] = item.value
		end
		save(player)
		shopSync(player)
		return true, "Bought " .. item.name .. "!"
	elseif action == "equip" then
		if not item.slot or not prof.Owned[id] then
			return false, "You don't own that."
		end
		if prof.Equip[item.slot] == item.value then
			prof.Equip[item.slot] = nil -- unequip
		else
			prof.Equip[item.slot] = item.value
		end
		if item.slot == "skin" and prof.Equip.skin then
			task.defer(grant, player, "dressed")
		end
		save(player)
		shopSync(player)
		return true, prof.Equip[item.slot] and ("Equipped " .. item.name .. ".") or ("Unequipped " .. item.name .. ".")
	end
	return false, "?"
end

local function load(player)
	local prof = { Completed = {}, loaded = store == nil, Cash = 0, Owned = {}, Equip = {}, Spare = 0, Secrets = {}, Ach = {}, Wins = 0, Spent = 0, Best = {}, Settings = {}, LastDay = 0, Streak = 0, BestTime = {} }
	progress[player] = prof
	if store then
		for _ = 1, 3 do
			local ok, data = pcall(function()
				return store:GetAsync("p_" .. player.UserId)
			end)
			if ok then
				prof.loaded = true
				prof.firstTime = data == nil
				if type(data) == "table" and type(data.Completed) == "table" then
					for k, v in data.Completed do
						prof.Completed[tostring(k)] = v == true
					end
				end
				if type(data) == "table" then
					prof.Cash = math.max(0, math.floor(tonumber(data.Cash) or 0))
					prof.Spare = math.clamp(math.floor(tonumber(data.Spare) or 0), 0, 5)
					if type(data.Secrets) == "table" then
						for k, v in data.Secrets do
							prof.Secrets[tostring(k)] = v == true
						end
					end
					if type(data.Ach) == "table" then
						for k, v in data.Ach do
							prof.Ach[tostring(k)] = v == true
						end
					end
					prof.Wins = math.max(0, math.floor(tonumber(data.Wins) or 0))
					prof.Spent = math.max(0, math.floor(tonumber(data.Spent) or 0))
					if type(data.Best) == "table" then
						for k, v in data.Best do
							prof.Best[tostring(k)] = tonumber(v) or 0
						end
					end
					for _, key in { "Settings", "BestTime" } do
						if type(data[key]) == "table" then
							for k, v in data[key] do
								prof[key][tostring(k)] = tonumber(v)
							end
						end
					end
					prof.LastDay = tonumber(data.LastDay) or 0
					prof.Streak = tonumber(data.Streak) or 0
					if type(data.Owned) == "table" then
						for k, v in data.Owned do
							prof.Owned[tostring(k)] = v == true
						end
					end
					if type(data.Equip) == "table" then
						for k, v in data.Equip do
							prof.Equip[tostring(k)] = tostring(v)
						end
					end
				end
				break
			end
			task.wait(1)
		end
	end
	if not prof.loaded and RunService:IsStudio() then
		prof.loaded = true -- (Studio without data access) let the shop work for testing
	end
	-- Coming back from a chapter? Bank what you earned there (capped so nobody can fake a fortune)
	local join = player:GetJoinData()
	local data = join and join.TeleportData
	if type(data) == "table" and type(data.Earned) == "number" and data.Earned > 0 then
		local earned = math.clamp(math.floor(data.Earned), 0, 2000)
		prof.Cash += earned
		save(player)
		task.delay(5.5, function()
			if player.Parent then
				Notify:FireClient(player, ("You banked $%d from that run! Spend it at the BLACK MARKET stall."):format(earned))
			end
		end)
	end
	if RunService:IsStudio() and prof.Cash < 1000 then
		prof.Cash = 3000 -- (Studio only) test money
	end
	if type(data) == "table" and type(data.Completed) == "number" then
		if not prof.Completed[tostring(data.Completed)] then
			prof.Completed[tostring(data.Completed)] = true
			save(player)
			task.delay(4, function()
				if player.Parent then
					Notify:FireClient(player, data.Completed >= 4 and "Chapter 4 complete! Chapter 5 - THE ISLAND, the finale - is coming soon..." or ("Chapter %d complete! Chapter %d is unlocked."):format(data.Completed, data.Completed + 1))
				end
			end)
		end
	end
	-- secret endings (found the hidden item in a chapter, then won)
	if type(data) == "table" and type(data.Secret) == "number" and data.Secret >= 1 and data.Secret <= 4 then
		local k = tostring(math.floor(data.Secret))
		if not prof.Secrets[k] then
			prof.Secrets[k] = true
			save(player)
			local n = 0
			for _ in prof.Secrets do
				n += 1
			end
			task.delay(8, function()
				if player.Parent then
					Notify:FireClient(player, ("SECRET ENDING %s unlocked! Secrets found: %d/4"):format(k, n))
				end
			end)
		end
	end
	local secretCount = 0
	for _ in prof.Secrets do
		secretCount += 1
	end
	player:SetAttribute("Secrets", secretCount)
	refreshUnlock(player)
	shopSync(player)
	settingsSync(player)
	-- DAILY REWARD: come back each day; days in a row pay more (up to day 7)
	if prof.loaded then
		local today = math.floor(os.time() / 86400)
		if (prof.LastDay or 0) ~= today then
			local streak = ((prof.LastDay or 0) == today - 1) and math.min((prof.Streak or 0) + 1, 7) or 1
			prof.LastDay, prof.Streak = today, streak
			local amount = 50 + 25 * (streak - 1)
			prof.Cash += amount
			save(player)
			shopSync(player)
			task.delay(3, function()
				if player.Parent then
					DailyRemote:FireClient(player, streak, amount)
				end
			end)
		end
	end
	achSync(player)
	-- ACHIEVEMENTS: check what this player has earned (a moment later, so the pop-ups show once you've loaded in)
	task.delay(6, function()
		if not player.Parent or not prof.loaded then
			return
		end
		if type(data) == "table" and type(data.Completed) == "number" then
			prof.Wins = (prof.Wins or 0) + 1
			local run
			if type(data.Run) == "string" then
				pcall(function()
					run = HttpService:JSONDecode(data.Run)
				end)
			end
			if type(run) == "table" then
				local RANK = { Easy = 1, Normal = 2, Hard = 3, Nightmare = 4 }
				local chKey = tostring(math.floor(data.Completed))
				local rank = RANK[run.d] or 0
				if rank > (tonumber(prof.Best[chKey]) or 0) then
					prof.Best[chKey] = rank
				end
				local secs = tonumber(run.t)
				if secs and secs >= 30 and secs < (tonumber(prof.BestTime[chKey]) or math.huge) then
					secs = math.floor(secs)
					prof.BestTime[chKey] = secs
					task.spawn(function()
						pcall(function()
							DataStoreService:GetOrderedDataStore("BestTime_ch" .. chKey):SetAsync("p_" .. player.UserId, secs)
						end)
					end)
					Notify:FireClient(player, ("NEW PERSONAL BEST on Chapter %s: %d:%02d"):format(chKey, secs // 60, secs % 60))
				end
				local t5 = tonumber(run.t)
				if t5 and t5 > 0 and t5 < 300 then
					grant(player, "speed5")
				end
				if tonumber(run.l) == 1 then
					grant(player, "thread")
				end
				if (tonumber(run.c) or 0) >= 5 then
					grant(player, "nevergiveup")
				end
				if (tonumber(run.n) or 0) >= 6 then
					grant(player, "fullparty")
				end
				if run.d == "Hard" or run.d == "Nightmare" then
					grant(player, "hard")
				end
				if run.d == "Nightmare" then
					grant(player, "nightmare")
				end
				if tonumber(run.c) == 0 then
					grant(player, "flawless")
				end
				local t = tonumber(run.t)
				if t and t > 0 and t < 600 then
					grant(player, "speed")
				end
				local n = tonumber(run.n)
				if n and n >= 3 then
					grant(player, "squad")
				elseif n == 1 then
					grant(player, "solo")
				end
			end
			save(player)
		end
		for ch = 1, 4 do
			if prof.Completed[tostring(ch)] then
				grant(player, "ch" .. ch)
			end
		end
		if (prof.Wins or 0) >= 10 then
			grant(player, "veteran")
		end
		if (prof.Wins or 0) >= 25 then
			grant(player, "veteran25")
		end
		if (prof.Wins or 0) >= 50 then
			grant(player, "veteran50")
		end
		local hardAll, nightmareAll = true, true
		for ch = 1, 4 do
			local b = tonumber(prof.Best[tostring(ch)]) or 0
			if b < 3 then
				hardAll = false
			end
			if b < 4 then
				nightmareAll = false
			end
		end
		if hardAll then
			grant(player, "hardall")
		end
		if nightmareAll then
			grant(player, "nightmareall")
		end
		local sc = 0
		for _ in prof.Secrets do
			sc += 1
		end
		if sc >= 1 then
			grant(player, "secret1")
		end
		if sc >= 2 then
			grant(player, "secret2")
		end
		if sc >= 4 then
			grant(player, "secret4")
		end
		shopAch(player)
		if prof.Equip.skin and prof.Equip.skin ~= "" then
			grant(player, "dressed")
		end
	end)
	-- brand new (no saved data yet), or Studio: show the how-to-play guide
	player:SetAttribute("FirstTime", prof.firstTime == true or RunService:IsStudio() or next(prof.Completed) == nil)
end

Players.PlayerAdded:Connect(function(p)
	p:SetAttribute("InGame", false)
	task.spawn(load, p)
	p.CharacterAdded:Connect(function()
		p:SetAttribute("InGame", false)
	end)
end)
for _, p in Players:GetPlayers() do
	task.spawn(load, p)
end
Players.PlayerRemoving:Connect(function(p)
	save(p)
	progress[p] = nil
end)

-- Queue + departure ----------------------------------------------------------------------
local function rootOf(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health > 0 then
		return root
	end
end
local function inZone(player, zone)
	if player:GetAttribute("InGame") then
		return false
	end
	local root = rootOf(player)
	if not root then
		return false
	end
	local p = zone.CFrame:PointToObjectSpace(root.Position)
	local h = zone.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y + 2 and math.abs(p.Z) <= h.Z
end

local function depart(van, riders)
	local placeId = PlaceIds[van.place] or 0
	if placeId == 0 then
		for _, p in riders do
			Notify:FireClient(p, van.name .. " is coming soon!")
		end
		return
	end
	if RunService:IsStudio() then
		for _, p in riders do
			Notify:FireClient(p, "Teleports only work in the published game. Test each chapter in its own place.")
		end
		return
	end
	for _, p in riders do
		Departing:FireClient(p)
	end
	task.wait(1.5)
	local byUser = {}
	for _, p in riders do
		byUser[tostring(p.UserId)] = upgradesFor(p)
		save(p)
	end
	local data = { FromLobby = true, Chapter = van.chapter, Party = #riders, PartyId = HttpService:GenerateGUID(false), UpgradesByUser = byUser }
	-- A private server just for this van when possible, otherwise a public one.
	local ok, err = pcall(function()
		local code = TeleportService:ReserveServer(placeId)
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = code
		options:SetTeleportData(data)
		TeleportService:TeleportAsync(placeId, riders, options)
	end)
	if not ok then
		ok, err = pcall(function()
			local options = Instance.new("TeleportOptions")
			options:SetTeleportData(data)
			TeleportService:TeleportAsync(placeId, riders, options)
		end)
	end
	if ok then
		-- spare lives ride along once and are used up
		for _, p in riders do
			local prof = progress[p]
			if prof and (prof.Spare or 0) > 0 then
				prof.Spare = 0
				save(p)
			end
		end
	end
	if not ok then
		warn("Teleport failed: " .. tostring(err))
		for _, p in riders do
			Notify:FireClient(p, "The van broke down (teleport failed). Try again!")
		end
	end
end

local function runVan(van)
	local zone = van.model:WaitForChild("VanZone")
	local status = van.model:WaitForChild("BillboardAnchor"):WaitForChild("Queue"):WaitForChild("Status")
	local timeLeft
	local warned = {}
	while true do
		local riders = {}
		for _, p in Players:GetPlayers() do
			if inZone(p, zone) then
				if van.requires and not hasBeaten(p, van.requires) then
					-- locked: step them back out
					local root = rootOf(p)
					if root then
						root.CFrame = zone.CFrame * CFrame.new(0, 0, zone.Size.Z / 2 + 4)
					end
					if not warned[p] or os.clock() - warned[p] > 3 then
						warned[p] = os.clock()
						Notify:FireClient(p, ("Locked. Beat Chapter %d first!"):format(van.requires))
					end
				elseif #riders < MAX_PLAYERS then
					table.insert(riders, p)
				end
			end
		end
		if #riders == 0 then
			timeLeft = nil
			status.Text = (PlaceIds[van.place] or 0) == 0 and "Coming soon" or "Step behind the van to join"
		else
			timeLeft = timeLeft or COUNTDOWN
			status.Text = ("Players %d/%d  -  leaving in %d"):format(#riders, MAX_PLAYERS, math.ceil(timeLeft))
			if timeLeft <= 0 then
				status.Text = "Leaving..."
				depart(van, riders)
				timeLeft = nil
				task.wait(2)
			end
		end
		task.wait(0.25)
		if timeLeft then
			timeLeft -= 0.25
		end
	end
end

for _, van in VANS do
	task.spawn(runVan, van)
end
