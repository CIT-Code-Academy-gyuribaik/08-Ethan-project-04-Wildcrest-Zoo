-- Shows the goal + controls once the round starts (after the intro and the difficulty pick)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local GOAL = "Trap B-00 in the mall's capture cage: power the generator, prepare the drugged bait, pull the lever and lock the clamps. Then radio Wildcrest and survive the ride."
local gui = Instance.new("ScreenGui")
gui.Name = "ControlsCard"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")
local card = Instance.new("Frame")
card.Size = UDim2.fromOffset(560, 196)
card.Position = UDim2.new(0.5, -280, 1, 10)
card.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
card.BackgroundTransparency = 0.1
card.Parent = gui
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
local stroke = Instance.new("UIStroke", card)
stroke.Color = Color3.fromRGB(255, 220, 80)
stroke.Thickness = 2
local function text(t, y, h, size, color, font)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -30, 0, h)
	l.Position = UDim2.fromOffset(15, y)
	l.BackgroundTransparency = 1
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Font = font or Enum.Font.Gotham
	l.TextSize = size
	l.TextColor3 = color
	l.Text = t
	l.Parent = card
	return l
end
text("YOUR GOAL", 10, 22, 16, Color3.fromRGB(255, 220, 80), Enum.Font.GothamBlack)
text(GOAL, 32, 46, 17, Color3.fromRGB(240, 240, 235), Enum.Font.GothamBold)
text("SHIFT sprint   F flashlight   E hide / leave   Q stun gun   G flare   C dash\nH objective marker   M free the mouse\nFollow the objective (top-left) and the yellow marker.", 86, 66, 15, Color3.fromRGB(200, 200, 195))
text("(this card hides in a few seconds)", 166, 20, 13, Color3.fromRGB(140, 140, 140))
local shown = false
local function showCard()
	if shown then
		return
	end
	shown = true
	TweenService:Create(card, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, -280, 1, -230) }):Play()
	task.delay(14, function()
		TweenService:Create(card, TweenInfo.new(0.6), { Position = UDim2.new(0.5, -280, 1, 10) }):Play()
	end)
end
local function check()
	local d = RS:GetAttribute("Difficulty")
	if type(d) == "string" and d ~= "" and RS:GetAttribute("DifficultyChoosing") ~= true then
		task.delay(1.5, showCard)
	end
end
RS:GetAttributeChangedSignal("Difficulty"):Connect(check)
RS:GetAttributeChangedSignal("DifficultyChoosing"):Connect(check)
task.delay(3, check)
