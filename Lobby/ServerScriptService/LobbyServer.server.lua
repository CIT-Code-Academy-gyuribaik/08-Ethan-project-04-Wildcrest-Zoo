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
			store:SetAsync("p_" .. player.UserId, { Completed = prof.Completed, Cash = prof.Cash, Owned = prof.Owned, Equip = prof.Equip, Spare = prof.Spare })
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
		save(player)
		shopSync(player)
		return true, prof.Equip[item.slot] and ("Equipped " .. item.name .. ".") or ("Unequipped " .. item.name .. ".")
	end
	return false, "?"
end

local function load(player)
	local prof = { Completed = {}, loaded = store == nil, Cash = 0, Owned = {}, Equip = {}, Spare = 0 }
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
	refreshUnlock(player)
	shopSync(player)
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
