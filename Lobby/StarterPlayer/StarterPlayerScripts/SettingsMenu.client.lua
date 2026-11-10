-- SETTINGS: brightness, mouse sensitivity, volume. Press [O] (or the SETTINGS button in the lobby).
-- Set in the lobby = saved and carried into every chapter by the van.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local DEFAULTS = { Bright = 5, Sens = 5, Vol = 8 }
local ROWS = { { key = "Bright", name = "Brightness" }, { key = "Sens", name = "Mouse sensitivity" }, { key = "Vol", name = "Volume" } }
local values = {}
local function get(k)
	return values[k] or player:GetAttribute("Set_" .. k) or DEFAULTS[k]
end

-- what the settings do
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "PlayerBrightness"
local function placeCC()
	cc.Parent = workspace.CurrentCamera
end
placeCC()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(placeCC)
local group = SoundService:FindFirstChild("PlayerVolume") or Instance.new("SoundGroup")
group.Name = "PlayerVolume"
group.Parent = SoundService
local function hook(s)
	if s:IsA("Sound") and s.SoundGroup == nil then
		s.SoundGroup = group
	end
end
for _, root in { workspace, SoundService, ReplicatedStorage, player:WaitForChild("PlayerGui") } do
	for _, d in root:GetDescendants() do
		pcall(hook, d)
	end
	root.DescendantAdded:Connect(function(d)
		pcall(hook, d)
	end)
end
local function apply()
	cc.Brightness = (get("Bright") - 5) * 0.06
	cc.Contrast = (get("Bright") - 5) * 0.02
	UserInputService.MouseDeltaSensitivity = 0.2 + get("Sens") * 0.16
	group.Volume = get("Vol") / 8
end
apply()
player.AttributeChanged:Connect(function(a)
	if a:sub(1, 4) == "Set_" then
		values[a:sub(5)] = nil -- the saved value from the server wins until you change it here
		apply()
	end
end)

-- the menu
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
local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), { Name = "SettingsMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60 })
local panel = new("Frame", gui, { Size = UDim2.fromOffset(420, 290), Position = UDim2.new(0.5, -210, 0.5, -145), BackgroundColor3 = Color3.fromRGB(18, 18, 22), Visible = false })
corner(panel, 12)
new("UIStroke", panel, { Color = Color3.fromRGB(150, 180, 220), Thickness = 2 })
new("TextLabel", panel, { Size = UDim2.new(1, -80, 0, 44), Position = UDim2.fromOffset(18, 8), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 24,
	TextColor3 = Color3.fromRGB(190, 215, 255), TextXAlignment = Enum.TextXAlignment.Left, Text = "SETTINGS" })
local close = new("TextButton", panel, { Size = UDim2.fromOffset(40, 36), Position = UDim2.new(1, -52, 0, 10), BackgroundColor3 = Color3.fromRGB(70, 30, 30), Font = Enum.Font.GothamBlack,
	TextSize = 18, TextColor3 = Color3.new(1, 1, 1), Text = "X" })
corner(close, 6)
new("TextLabel", panel, { Size = UDim2.new(1, -36, 0, 22), Position = UDim2.new(0, 18, 1, -32), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 13,
	TextColor3 = Color3.fromRGB(150, 150, 150), TextXAlignment = Enum.TextXAlignment.Left, Text = "Press O to open or close. Set them in the lobby to keep them." })
local remote -- only the lobby saves settings
task.spawn(function()
	local f = ReplicatedStorage:WaitForChild("LobbyRemotes", 10)
	remote = f and f:WaitForChild("Settings", 10)
end)
local refreshers = {}
for i, row in ROWS do
	local y = 60 + (i - 1) * 64
	new("TextLabel", panel, { Size = UDim2.fromOffset(170, 40), Position = UDim2.fromOffset(18, y), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 17,
		TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, Text = row.name })
	local minus = new("TextButton", panel, { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(196, y), BackgroundColor3 = Color3.fromRGB(45, 45, 55), Font = Enum.Font.GothamBlack,
		TextSize = 22, TextColor3 = Color3.new(1, 1, 1), Text = "-" })
	corner(minus, 6)
	local bar = new("Frame", panel, { Size = UDim2.fromOffset(110, 12), Position = UDim2.fromOffset(244, y + 14), BackgroundColor3 = Color3.fromRGB(40, 40, 48) })
	corner(bar, 6)
	local fill = new("Frame", bar, { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = Color3.fromRGB(150, 190, 255) })
	corner(fill, 6)
	local plus = new("TextButton", panel, { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(362, y), BackgroundColor3 = Color3.fromRGB(45, 45, 55), Font = Enum.Font.GothamBlack,
		TextSize = 22, TextColor3 = Color3.new(1, 1, 1), Text = "+" })
	corner(plus, 6)
	local function refresh()
		fill.Size = UDim2.fromScale(math.max(get(row.key), 0.3) / 10, 1)
	end
	table.insert(refreshers, refresh)
	local function change(d)
		values[row.key] = math.clamp(get(row.key) + d, 0, 10)
		apply()
		refresh()
		if remote then
			remote:FireServer(row.key, values[row.key])
		end
	end
	minus.MouseButton1Click:Connect(function()
		change(-1)
	end)
	plus.MouseButton1Click:Connect(function()
		change(1)
	end)
end
local function setOpen(on)
	panel.Visible = on
	for _, r in refreshers do
		r()
	end
end
close.MouseButton1Click:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.O then
		setOpen(not panel.Visible)
	elseif input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
		setOpen(false)
	end
end)
if script:GetAttribute("ShowButton") then
	local btn = new("TextButton", gui, { Size = UDim2.fromOffset(150, 36), Position = UDim2.new(0, 16, 0, 152), BackgroundColor3 = Color3.fromRGB(20, 28, 40), BackgroundTransparency = 0.15,
		Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = Color3.fromRGB(190, 215, 255), Text = "SETTINGS [O]" })
	corner(btn)
	btn.MouseButton1Click:Connect(function()
		setOpen(not panel.Visible)
	end)
end
-- small corner button for phones / tablets (no O key there)
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not script:GetAttribute("ShowButton") then
	local gear = new("TextButton", gui, { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -56, 0, 64), BackgroundColor3 = Color3.fromRGB(20, 28, 40), BackgroundTransparency = 0.2,
		Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = Color3.fromRGB(190, 215, 255), Text = "⚙" })
	corner(gear, 22)
	gear.MouseButton1Click:Connect(function()
		setOpen(not panel.Visible)
	end)
end
-- first person: free the mouse while the menu is open
RunService:BindToRenderStep("SettingsMouse", Enum.RenderPriority.Camera.Value + 13, function()
	if panel.Visible then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end)
