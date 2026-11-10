-- Lobby: ACHIEVEMENTS button + list + "achievement unlocked" pop-ups
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local List = require(ReplicatedStorage:WaitForChild("AchievementList"))
local remotes = ReplicatedStorage:WaitForChild("LobbyRemotes")
local AchRemote = remotes:WaitForChild("Achievement")
local GOLD = Color3.fromRGB(255, 210, 90)

local function new(cls, parent, props)
	local o = Instance.new(cls)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(o, r)
	new("UICorner", o, { CornerRadius = UDim.new(0, r or 8) })
end

local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), { Name = "LobbyAchievements", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 15 })
local btn = new("TextButton", gui, { Size = UDim2.fromOffset(150, 36), Position = UDim2.new(0, 16, 0, 108), BackgroundColor3 = Color3.fromRGB(40, 32, 12), BackgroundTransparency = 0.15,
	Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = GOLD, Text = "ACHIEVEMENTS" })
corner(btn)

-- the list
local panel = new("Frame", gui, { Size = UDim2.fromOffset(580, 460), Position = UDim2.new(0.5, -290, 0.5, -230), BackgroundColor3 = Color3.fromRGB(18, 18, 22), Visible = false, ZIndex = 20 })
corner(panel, 12)
new("UIStroke", panel, { Color = GOLD, Thickness = 2 })
local head = new("TextLabel", panel, { Size = UDim2.new(1, -80, 0, 46), Position = UDim2.fromOffset(18, 8), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 26,
	TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Text = "ACHIEVEMENTS", ZIndex = 21 })
local close = new("TextButton", panel, { Size = UDim2.fromOffset(40, 36), Position = UDim2.new(1, -52, 0, 12), BackgroundColor3 = Color3.fromRGB(70, 30, 30), Font = Enum.Font.GothamBlack,
	TextSize = 18, TextColor3 = Color3.new(1, 1, 1), Text = "X", ZIndex = 22 })
corner(close, 6)
local scroll = new("ScrollingFrame", panel, { Size = UDim2.new(1, -28, 1, -70), Position = UDim2.fromOffset(14, 58), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 21 })
new("UIListLayout", scroll, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
local rows = {}
for i, a in List do
	local row = new("Frame", scroll, { Size = UDim2.new(1, -10, 0, 56), BackgroundColor3 = Color3.fromRGB(30, 30, 34), LayoutOrder = i, ZIndex = 21 })
	corner(row, 8)
	local icon = new("TextLabel", row, { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.fromRGB(50, 50, 56), Font = Enum.Font.GothamBlack,
		TextSize = 22, TextColor3 = Color3.fromRGB(140, 140, 140), Text = "?", ZIndex = 22 })
	corner(icon, 20)
	local name = new("TextLabel", row, { Size = UDim2.new(1, -170, 0, 24), Position = UDim2.fromOffset(58, 5), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 17,
		TextColor3 = Color3.fromRGB(200, 200, 200), TextXAlignment = Enum.TextXAlignment.Left, Text = a.name, ZIndex = 22 })
	new("TextLabel", row, { Size = UDim2.new(1, -170, 0, 20), Position = UDim2.fromOffset(58, 29), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 14,
		TextColor3 = Color3.fromRGB(165, 165, 160), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = a.desc, ZIndex = 22 })
	local reward = new("TextLabel", row, { Size = UDim2.fromOffset(100, 40), Position = UDim2.new(1, -108, 0, 8), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 16,
		TextColor3 = Color3.fromRGB(130, 255, 150), Text = ("+$%d"):format(a.reward), ZIndex = 22 })
	rows[a.id] = { row = row, icon = icon, name = name, reward = reward }
end
local function refresh()
	local n = 0
	for _, a in List do
		local r = rows[a.id]
		local has = player:GetAttribute("Ach_" .. a.id) == true
		if has then
			n += 1
		end
		r.row.BackgroundColor3 = has and Color3.fromRGB(44, 38, 20) or Color3.fromRGB(30, 30, 34)
		r.icon.Text = has and "★" or "?"
		r.icon.TextColor3 = has and Color3.fromRGB(30, 24, 8) or Color3.fromRGB(140, 140, 140)
		r.icon.BackgroundColor3 = has and GOLD or Color3.fromRGB(50, 50, 56)
		r.name.TextColor3 = has and GOLD or Color3.fromRGB(200, 200, 200)
		r.reward.Text = has and "DONE" or ("+$%d"):format(a.reward)
		r.reward.TextColor3 = has and GOLD or Color3.fromRGB(130, 255, 150)
	end
	btn.Text = ("ACHIEVEMENTS %d/%d"):format(n, #List)
	head.Text = ("ACHIEVEMENTS  %d/%d"):format(n, #List)
end
player.AttributeChanged:Connect(function(attr)
	if attr:sub(1, 4) == "Ach_" then
		refresh()
	end
end)
refresh()
local function setOpen(on)
	panel.Visible = on
	if on then
		refresh()
	end
end
btn.MouseButton1Click:Connect(function()
	setOpen(not panel.Visible)
end)
close.MouseButton1Click:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
		setOpen(false)
	end
end)
-- first person: free the mouse while the list is open
RunService:BindToRenderStep("AchMouse", Enum.RenderPriority.Camera.Value + 12, function()
	if panel.Visible then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end)

-- "ACHIEVEMENT UNLOCKED" pop-ups, one after another
local byId = {}
for _, a in List do
	byId[a.id] = a
end
local queue, showing = {}, false
local function showNext()
	if showing or #queue == 0 then
		return
	end
	showing = true
	local item = table.remove(queue, 1)
	local a = type(item) == "table" and item or byId[item]
	if not a then
		showing = false
		showNext()
		return
	end
	local card = new("Frame", gui, { Size = UDim2.fromOffset(420, 74), Position = UDim2.new(0.5, -210, 0, -90), BackgroundColor3 = Color3.fromRGB(24, 20, 10), ZIndex = 40 })
	corner(card, 10)
	new("UIStroke", card, { Color = GOLD, Thickness = 2 })
	new("TextLabel", card, { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 6), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14,
		TextColor3 = GOLD, Text = a.header or "★ ACHIEVEMENT UNLOCKED ★", ZIndex = 41 })
	new("TextLabel", card, { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 32), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1), Text = ("%s   +$%d"):format(a.name, a.reward), ZIndex = 41 })
	local s = new("Sound", card, { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6 })
	s:Play()
	TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, -210, 0, 20) }):Play()
	task.delay(3.4, function()
		TweenService:Create(card, TweenInfo.new(0.4), { Position = UDim2.new(0.5, -210, 0, -90) }):Play()
		task.wait(0.5)
		card:Destroy()
		showing = false
		showNext()
	end)
end
AchRemote.OnClientEvent:Connect(function(id)
	table.insert(queue, id)
	showNext()
end)
-- daily login reward pop-up
remotes:WaitForChild("Daily").OnClientEvent:Connect(function(day, amount)
	table.insert(queue, { header = ("DAILY REWARD - DAY %d"):format(day), name = day >= 7 and "Max streak!" or "Come back tomorrow for more", reward = amount })
	showNext()
end)
