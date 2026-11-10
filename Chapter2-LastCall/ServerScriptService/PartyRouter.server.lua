-- Every party from a lobby van gets its OWN private server of this chapter.
-- (The lobby is a different experience, so it can't reserve servers here - we do it on arrival.)
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
if RunService:IsStudio() or game.PrivateServerId ~= "" then
	return -- Studio, or already on a party's private server: just play
end
local function banner(p, text)
	local pg = p:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local g = pg:FindFirstChild("RouteBanner") or Instance.new("ScreenGui")
	g.Name = "RouteBanner"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 100
	g.Parent = pg
	local l = g:FindFirstChild("Text") or Instance.new("TextLabel")
	l.Name = "Text"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundColor3 = Color3.new(0, 0, 0)
	l.BackgroundTransparency = 0
	l.TextColor3 = Color3.fromRGB(235, 230, 220)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 24
	l.Text = text
	l.Parent = g
end
local groups = {}
local function send(id)
	local g = groups[id]
	if not g or g.started then
		return
	end
	g.started = true
	local list = {}
	for _, p in g.players do
		if p.Parent then
			table.insert(list, p)
		end
	end
	if #list == 0 then
		groups[id] = nil
		return
	end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			local code = TeleportService:ReserveServer(game.PlaceId)
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = code
			if type(g.data) == "table" then
				options:SetTeleportData(g.data)
			end
			TeleportService:TeleportAsync(game.PlaceId, list, options)
		end)
		if ok then
			groups[id] = nil
			return
		end
		warn("PartyRouter attempt " .. attempt .. ": " .. tostring(err))
		task.wait(2)
	end
	for _, p in list do
		p:SetAttribute("RouteFailed", true)
		local pg = p:FindFirstChildOfClass("PlayerGui")
		if pg and pg:FindFirstChild("RouteBanner") then
			pg.RouteBanner:Destroy()
		end
		p:LoadCharacter()
	end
	groups[id] = nil
end
Players.PlayerAdded:Connect(function(p)
	local td
	pcall(function()
		td = p:GetJoinData().TeleportData
	end)
	-- Found this chapter by search (not from a lobby van)? Chapters start in the LOBBY.
	local fromLobby = type(td) == "table" and td.FromLobby == true
	local isOwner = game.CreatorType == Enum.CreatorType.User and p.UserId == game.CreatorId
	if not fromLobby and not isOwner then
		task.defer(banner, p, "Closing Time starts in the LOBBY.\nTaking you there now...")
		task.delay(3, function()
			if not p.Parent then
				return
			end
			local ok = pcall(function()
				local PlaceIds = require(game:GetService("ReplicatedStorage"):WaitForChild("PlaceIds"))
				TeleportService:TeleportAsync(PlaceIds.Lobby, { p })
			end)
			if not ok and p.Parent then
				-- couldn't send you: just play here
				p:SetAttribute("RouteFailed", true)
				local pg = p:FindFirstChildOfClass("PlayerGui")
				if pg and pg:FindFirstChild("RouteBanner") then
					pg.RouteBanner:Destroy()
				end
				p:LoadCharacter()
			end
		end)
		return
	end
	local id = (type(td) == "table" and type(td.PartyId) == "string") and td.PartyId or ("solo_" .. p.UserId)
	local expected = (type(td) == "table" and tonumber(td.Party)) or 1
	local g = groups[id]
	if not g then
		g = { players = {}, expected = math.clamp(expected, 1, 12), data = td, started = false }
		groups[id] = g
		task.delay(8, function()
			send(id)
		end)
	end
	table.insert(g.players, p)
	task.defer(banner, p, "Taking your party to its own server...")
	if #g.players >= g.expected then
		task.delay(1, send, id)
	end
end)
