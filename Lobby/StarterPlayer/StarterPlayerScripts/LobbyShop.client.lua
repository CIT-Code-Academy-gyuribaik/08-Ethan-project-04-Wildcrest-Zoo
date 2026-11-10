-- Lobby: cash display + the Black Market shop (buy flashlights, beam skins, outfits, skills)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Catalog = require(ReplicatedStorage:WaitForChild("ShopCatalog"))
local remotes = ReplicatedStorage:WaitForChild("LobbyRemotes")
local ShopRF = remotes:WaitForChild("Shop")

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyShopGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")
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
-- cash in the corner
local cashLbl = new("TextLabel", gui, { Size = UDim2.fromOffset(260, 34), Position = UDim2.new(1, -280, 0, 64), BackgroundTransparency = 0.35, BackgroundColor3 = Color3.fromRGB(15, 25, 18),
	TextColor3 = Color3.fromRGB(130, 255, 150), Font = Enum.Font.GothamBlack, TextSize = 20, Text = "$0" })
corner(cashLbl)
local function refreshCash()
	cashLbl.Text = ("$%d"):format(player:GetAttribute("Cash") or 0)
end
player:GetAttributeChangedSignal("Cash"):Connect(refreshCash)
refreshCash()
-- secret endings found (each chapter hides one strange item)
local secretLbl = new("TextLabel", gui, { Size = UDim2.fromOffset(260, 26), Position = UDim2.new(1, -280, 0, 102), BackgroundTransparency = 0.35, BackgroundColor3 = Color3.fromRGB(28, 18, 40),
	TextColor3 = Color3.fromRGB(205, 180, 255), Font = Enum.Font.GothamBold, TextSize = 14, Text = "" })
corner(secretLbl)
local function refreshSecrets()
	secretLbl.Text = ("SECRET ENDINGS: %d/4  (find the ??? item)"):format(player:GetAttribute("Secrets") or 0)
end
player:GetAttributeChangedSignal("Secrets"):Connect(refreshSecrets)
refreshSecrets()

-- the shop window
local win = new("Frame", gui, { Size = UDim2.fromOffset(640, 470), Position = UDim2.new(0.5, -320, 0.5, -235), BackgroundColor3 = Color3.fromRGB(18, 20, 22), Visible = false, ZIndex = 10 })
corner(win, 12)
new("UIStroke", win, { Color = Color3.fromRGB(80, 200, 110), Thickness = 2 })
new("TextLabel", win, { Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(16, 8), BackgroundTransparency = 1, Text = "BLACK MARKET SUPPLIES", Font = Enum.Font.GothamBlack, TextSize = 26,
	TextColor3 = Color3.fromRGB(130, 255, 150), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11 })
local winCash = new("TextLabel", win, { Size = UDim2.fromOffset(200, 44), Position = UDim2.new(1, -260, 0, 8), BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamBold, TextSize = 20,
	TextColor3 = Color3.fromRGB(230, 230, 200), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 11 })
local close = new("TextButton", win, { Size = UDim2.fromOffset(40, 36), Position = UDim2.new(1, -50, 0, 12), BackgroundColor3 = Color3.fromRGB(70, 30, 30), Text = "X", Font = Enum.Font.GothamBlack, TextSize = 18,
	TextColor3 = Color3.new(1, 1, 1), ZIndex = 12 })
corner(close, 6)
local status = new("TextLabel", win, { Size = UDim2.new(1, -32, 0, 26), Position = UDim2.new(0, 16, 1, -34), BackgroundTransparency = 1, Text = "Your purchases come with you into every chapter.", Font = Enum.Font.Gotham,
	TextSize = 15, TextColor3 = Color3.fromRGB(180, 180, 170), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11 })
local list = new("ScrollingFrame", win, { Size = UDim2.new(1, -32, 1, -100), Position = UDim2.fromOffset(16, 58), BackgroundTransparency = 1, ScrollBarThickness = 6, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, ZIndex = 11 })
new("UIListLayout", list, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
local rows = {}
local kindColor = { Consumable = Color3.fromRGB(255, 120, 140), Flashlight = Color3.fromRGB(255, 220, 120), ["Flashlight Skin"] = Color3.fromRGB(170, 200, 255), Outfit = Color3.fromRGB(255, 170, 120), Skill = Color3.fromRGB(200, 150, 255) }
for i, item in Catalog do
	local row = new("Frame", list, { Size = UDim2.new(1, -10, 0, 54), BackgroundColor3 = Color3.fromRGB(30, 33, 36), LayoutOrder = i, ZIndex = 11 })
	corner(row, 8)
	new("TextLabel", row, { Size = UDim2.new(1, -170, 0, 24), Position = UDim2.fromOffset(12, 4), BackgroundTransparency = 1, Text = item.name .. "   <font color=\"#888888\">" .. item.kind .. "</font>", RichText = true,
		Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = kindColor[item.kind] or Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 })
	new("TextLabel", row, { Size = UDim2.new(1, -170, 0, 20), Position = UDim2.fromOffset(12, 28), BackgroundTransparency = 1, Text = item.desc, Font = Enum.Font.Gotham, TextSize = 14,
		TextColor3 = Color3.fromRGB(190, 190, 185), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 12 })
	local btn = new("TextButton", row, { Size = UDim2.fromOffset(140, 38), Position = UDim2.new(1, -150, 0.5, -19), BackgroundColor3 = Color3.fromRGB(40, 120, 60), Font = Enum.Font.GothamBlack, TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1), Text = "", ZIndex = 12 })
	corner(btn, 6)
	rows[item.id] = { item = item, btn = btn }
	btn.MouseButton1Click:Connect(function()
		local owned = player:GetAttribute("Own_" .. item.id)
		local ok, msg = ShopRF:InvokeServer((owned and not item.consumable) and "equip" or "buy", item.id)
		status.Text = msg or ""
		status.TextColor3 = ok and Color3.fromRGB(130, 255, 150) or Color3.fromRGB(255, 130, 120)
	end)
end
local function refreshRows()
	winCash.Text = ("You have $%d"):format(player:GetAttribute("Cash") or 0)
	for id, r in rows do
		local item = r.item
		local owned = player:GetAttribute("Own_" .. id)
		if item.consumable then
			local have = player:GetAttribute("Spare") or 0
			r.btn.Text = have >= (item.max or 5) and ("FULL (%d/%d)"):format(have, item.max or 5) or ("BUY $%d  (%d/%d)"):format(item.price, have, item.max or 5)
			r.btn.BackgroundColor3 = (have < (item.max or 5) and (player:GetAttribute("Cash") or 0) >= item.price) and Color3.fromRGB(40, 130, 60) or Color3.fromRGB(90, 45, 45)
			continue
		end
		if owned and item.slot then
			local on = player:GetAttribute("Eq_" .. item.slot) == item.value
			r.btn.Text = on and "EQUIPPED" or "EQUIP"
			r.btn.BackgroundColor3 = on and Color3.fromRGB(60, 90, 160) or Color3.fromRGB(70, 70, 80)
		elseif owned then
			r.btn.Text = "OWNED"
			r.btn.BackgroundColor3 = Color3.fromRGB(50, 55, 60)
		else
			r.btn.Text = ("BUY  $%d"):format(item.price)
			local can = (player:GetAttribute("Cash") or 0) >= item.price and (not item.requires or player:GetAttribute("Own_" .. item.requires))
			r.btn.BackgroundColor3 = can and Color3.fromRGB(40, 130, 60) or Color3.fromRGB(90, 45, 45)
		end
	end
end
player.AttributeChanged:Connect(function(a)
	if a == "Cash" or a == "Spare" or a:sub(1, 4) == "Own_" or a:sub(1, 3) == "Eq_" then
		refreshRows()
	end
end)
refreshRows()
local function setOpen(on)
	win.Visible = on
	player:SetAttribute("ShopOpen", on)
	if on then
		status.Text = "Your purchases come with you into every chapter."
		status.TextColor3 = Color3.fromRGB(180, 180, 170)
		refreshRows()
	end
end
close.MouseButton1Click:Connect(function()
	setOpen(false)
end)
local stall = workspace:WaitForChild("Lobby"):WaitForChild("ShopStall", 30)
-- listen for ANY shop prompt (works even if the stall loads in after this script starts)
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ShopPrompt" then
		setOpen(not win.Visible)
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and win.Visible then
		setOpen(false)
	end
end)
-- walk away and it closes
RunService.Heartbeat:Connect(function()
	if win.Visible and stall then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local counter = stall:FindFirstChild("Counter")
		if root and counter and (root.Position - counter.Position).Magnitude > 16 then
			setOpen(false)
		end
	end
end)
-- first person: free the mouse while the shop is open (or M toggled)
local freeMouse = false
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.M then
		freeMouse = not freeMouse
	end
end)
RunService:BindToRenderStep("FreeMouse", Enum.RenderPriority.Camera.Value + 10, function()
	if freeMouse or win.Visible then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end)
