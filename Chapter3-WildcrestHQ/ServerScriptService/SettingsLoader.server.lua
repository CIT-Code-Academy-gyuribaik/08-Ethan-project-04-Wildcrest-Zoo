-- Settings chosen in the lobby (brightness / sensitivity / volume) ride along in the van's teleport data
local Players = game:GetService("Players")
local function load(p)
	local td
	pcall(function()
		td = p:GetJoinData().TeleportData
	end)
	local u = type(td) == "table" and type(td.UpgradesByUser) == "table" and td.UpgradesByUser[tostring(p.UserId)]
	local s = type(u) == "table" and u.settings
	if type(s) == "table" then
		for _, k in { "Bright", "Sens", "Vol" } do
			local v = tonumber(s[k])
			if v then
				p:SetAttribute("Set_" .. k, math.clamp(math.floor(v), 0, 10))
			end
		end
	end
end
Players.PlayerAdded:Connect(load)
for _, p in Players:GetPlayers() do
	task.spawn(load, p)
end
