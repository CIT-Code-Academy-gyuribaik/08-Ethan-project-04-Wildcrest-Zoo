-- Lobby client: flickering lights, the title card, notices, and the van ride fade.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LobbyRemotes")

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- Title card on join
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 90)
title.Position = UDim2.fromScale(0, 0.18)
title.BackgroundTransparency = 1
title.Font = Enum.Font.Creepster
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(220, 200, 160)
title.TextStrokeTransparency = 0.4
title.Text = "CLOSING TIME"
title.Parent = gui
local sub = title:Clone()
sub.Size = UDim2.new(1, 0, 0, 30)
sub.Position = UDim2.fromScale(0, 0.18 + 0.12)
sub.Font = Enum.Font.SpecialElite
sub.TextColor3 = Color3.fromRGB(200, 200, 200)
sub.Text = "Read the memo. Then get in the van."
sub.Parent = gui
task.delay(6, function()
	for _, l in { title, sub } do
		TweenService:Create(l, TweenInfo.new(2), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end
end)

-- Notices
local notice = sub:Clone()
notice.Position = UDim2.fromScale(0, 0.7)
notice.TextTransparency = 1
notice.TextStrokeTransparency = 1
notice.Parent = gui
remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text)
	notice.Text = text
	notice.TextTransparency = 0
	notice.TextStrokeTransparency = 0.4
	task.delay(3, function()
		TweenService:Create(notice, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end)

-- Fade to black for the van ride
local fade = Instance.new("Frame")
fade.Size = UDim2.fromScale(1, 1)
fade.BackgroundColor3 = Color3.new(0, 0, 0)
fade.BackgroundTransparency = 1
fade.ZIndex = 10
fade.Parent = gui
remotes:WaitForChild("Departing").OnClientEvent:Connect(function()
	TweenService:Create(fade, TweenInfo.new(1.2), { BackgroundTransparency = 0 }):Play()
	task.delay(3, function()
		TweenService:Create(fade, TweenInfo.new(2), { BackgroundTransparency = 1 }):Play()
	end)
end)

-- Flickering lights (anything tagged "Flicker")
local function flicker(light)
	task.spawn(function()
		local base = light.Brightness
		local bulb = light.Parent
		local baseColor = bulb:IsA("BasePart") and bulb.Color
		while light.Parent do
			task.wait(math.random() * 4 + 0.5)
			for _ = 1, math.random(2, 6) do
				light.Brightness = base * math.random() * 0.3
				if baseColor then bulb.Color = baseColor:Lerp(Color3.new(0, 0, 0), 0.7) end
				task.wait(math.random() * 0.12 + 0.03)
				light.Brightness = base
				if baseColor then bulb.Color = baseColor end
				task.wait(math.random() * 0.15 + 0.03)
			end
		end
	end)
end
for _, l in CollectionService:GetTagged("Flicker") do
	flicker(l)
end
CollectionService:GetInstanceAddedSignal("Flicker"):Connect(flicker)

-- Chapter 2 / 3 vans: hide the lock sign once you've beaten the chapter before
for _, pair in { { "Van2", "Ch2Unlocked" }, { "Van3", "Ch3Unlocked" } } do task.spawn(function()
	local van2 = workspace:WaitForChild("Lobby"):WaitForChild(pair[1], 10)
	local sign = van2 and van2:FindFirstChild("LockSign")
	if not sign then
		return
	end
	local function refresh()
		local unlocked = player:GetAttribute(pair[2]) == true
		sign.Transparency = unlocked and 1 or 0
		for _, g in sign:GetDescendants() do
			if g:IsA("SurfaceGui") then
				g.Enabled = not unlocked
			end
		end
	end
	player:GetAttributeChangedSignal(pair[2]):Connect(refresh)
	refresh()
end) end
