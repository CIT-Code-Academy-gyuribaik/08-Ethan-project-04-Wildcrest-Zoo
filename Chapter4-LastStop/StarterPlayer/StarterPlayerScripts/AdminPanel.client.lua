-- ADMIN PANEL (Chapter 3): only the game's owner sees it; the server checks every command again. [P] opens it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
if not (RunService:IsStudio() or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)) then
	return
end
local Admin = ReplicatedStorage:WaitForChild("HQRemotes"):WaitForChild("Admin")
local gui = Instance.new("ScreenGui")
gui.Name = "AdminPanel" gui.ResetOnSpawn = false gui.DisplayOrder = 50 gui.IgnoreGuiInset = true gui.Parent = player:WaitForChild("PlayerGui")
local ACCENT = Color3.fromRGB(255, 190, 80)
local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r or 6) c.Parent = o end
local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.fromOffset(110, 26) openBtn.Position = UDim2.new(1, -134, 0, 100) openBtn.BackgroundColor3 = Color3.fromRGB(30, 22, 12)
openBtn.TextColor3 = ACCENT openBtn.Font = Enum.Font.GothamBold openBtn.TextSize = 13 openBtn.Text = "ADMIN [P]" openBtn.Parent = gui
corner(openBtn)
local panel = Instance.new("ScrollingFrame")
panel.Size = UDim2.fromOffset(240, 300) panel.Position = UDim2.new(1, -254, 0, 132) panel.CanvasSize = UDim2.new() panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
panel.ScrollBarThickness = 5 panel.ScrollBarImageColor3 = ACCENT panel.BorderSizePixel = 0 panel.BackgroundColor3 = Color3.fromRGB(16, 14, 12) panel.BackgroundTransparency = 0.08 panel.Visible = false panel.Parent = gui
corner(panel, 8)
local stroke = Instance.new("UIStroke") stroke.Color = ACCENT stroke.Transparency = 0.5 stroke.Parent = panel
local pad = Instance.new("UIPadding") pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 14) pad.Parent = panel
local list = Instance.new("UIListLayout") list.Padding = UDim.new(0, 5) list.SortOrder = Enum.SortOrder.LayoutOrder list.Parent = panel
local order = 0
local function header(text)
	order += 1
	local l = Instance.new("TextLabel") l.Size = UDim2.new(1, 0, 0, 18) l.BackgroundTransparency = 1 l.Font = Enum.Font.GothamBlack l.TextSize = 12 l.TextColor3 = ACCENT
	l.TextXAlignment = Enum.TextXAlignment.Left l.Text = text l.LayoutOrder = order l.Parent = panel
end
local function button(text, onClick)
	order += 1
	local b = Instance.new("TextButton") b.Size = UDim2.new(1, 0, 0, 28) b.BackgroundColor3 = Color3.fromRGB(38, 34, 30) b.TextColor3 = Color3.fromRGB(235, 230, 220)
	b.Font = Enum.Font.GothamBold b.TextSize = 13 b.TextXAlignment = Enum.TextXAlignment.Left b.Text = "   " .. text b.LayoutOrder = order b.Parent = panel
	corner(b, 5)
	b.MouseButton1Click:Connect(function() onClick(b) end)
	return b
end
local function toggle(text, onChange)
	local on = false
	local pill = Instance.new("TextLabel")
	local b = button(text, function()
		on = not on
		pill.Text = on and "ON" or "OFF"
		pill.BackgroundColor3 = on and Color3.fromRGB(90, 200, 110) or Color3.fromRGB(80, 70, 65)
		onChange(on)
	end)
	pill.Size = UDim2.fromOffset(40, 18) pill.AnchorPoint = Vector2.new(1, 0.5) pill.Position = UDim2.new(1, -6, 0.5, 0) pill.BackgroundColor3 = Color3.fromRGB(80, 70, 65)
	pill.Font = Enum.Font.GothamBlack pill.TextSize = 11 pill.TextColor3 = Color3.new(1, 1, 1) pill.Text = "OFF" pill.Parent = b
	corner(pill, 9)
end
local function send(cmd, v) Admin:FireServer(cmd, v) end
local function myRoot() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") end
local function tp(pos) local r = myRoot() if r then r.AssemblyLinearVelocity = Vector3.zero r.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end end
-- fly
local flyConn, vel, gyro, saved = nil, nil, nil, {}
local function setFly(on)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local r = myRoot()
	if flyConn then flyConn:Disconnect() flyConn = nil end
	if vel then vel:Destroy() vel = nil end
	if gyro then gyro:Destroy() gyro = nil end
	for p, cc in saved do if p.Parent then p.CanCollide = cc end end
	table.clear(saved)
	if hum then hum.PlatformStand = false end
	if not on or not r or not hum then return end
	hum.PlatformStand = true
	vel = Instance.new("BodyVelocity") vel.MaxForce = Vector3.new(1e6, 1e6, 1e6) vel.Velocity = Vector3.zero vel.Parent = r
	gyro = Instance.new("BodyGyro") gyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6) gyro.P = 2e4 gyro.Parent = r
	flyConn = RunService.Stepped:Connect(function()
		if not r.Parent then setFly(false) return end
		for _, p in char:GetDescendants() do if p:IsA("BasePart") and p.CanCollide then saved[p] = true p.CanCollide = false end end
		local cam = workspace.CurrentCamera
		local look = cam.CFrame.LookVector
		local move = hum.MoveDirection
		local dir = Vector3.zero
		if move.Magnitude > 0.05 then
			local flat = Vector3.new(look.X, 0, look.Z).Unit
			dir = move + Vector3.new(0, look.Y * move:Dot(flat), 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
		vel.Velocity = dir.Magnitude > 0 and dir.Unit * (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 120 or 55) or Vector3.zero
		gyro.CFrame = CFrame.lookAt(r.Position, r.Position + Vector3.new(look.X, 0, look.Z))
	end)
end
header("PLAYER")
toggle("God Mode", function(on) send("god", on) end)
toggle("Fly + No-clip", setFly)
toggle("Speed x2", function(on) player:SetAttribute("AdminSpeed", on and 2 or nil) end)
button("Refill stun gun", function() send("refill") end)
header("MONSTERS")
toggle("Freeze monsters", function(on) send("freeze", on) end)
button("Remove guards", function() send("clear") end)
header("TELEPORT")
button("To the objective marker", function()
	local bb = player.PlayerGui:FindFirstChild("ObjectiveMarker")
	local part = bb and bb.Adornee
	if part and part:IsA("BasePart") then tp(part.Position + Vector3.new(4, 0, 0)) end
end)
button("Your apartment (floor 12)", function() tp(Vector3.new(-30, 157, -23)) end)
button("Tower lobby", function() tp(Vector3.new(0, 3, -15)) end)
button("Old Town ticket hall", function() tp(Vector3.new(-45, -11, 88)) end)
button("Old Town platform", function() tp(Vector3.new(-50, -27, 150)) end)
button("Dark tunnel (middle)", function() tp(Vector3.new(-69.5, -31, 450)) end)
button("Construction station", function() tp(Vector3.new(-50, -27, 730)) end)
button("Sewers", function() tp(Vector3.new(-60, -55, 870)) end)
button("Control center", function() tp(Vector3.new(-60, -31, 1066)) end)
button("Last Stop platform", function() tp(Vector3.new(-50, -27, 1150)) end)
header("CHAPTER 4")
button("Skip to next step (story-safe)", function() send("skip") end)
button("WIN (end the chapter)", function() send("win") end)
local function fit()
	local h = workspace.CurrentCamera.ViewportSize.Y
	panel.Size = UDim2.fromOffset(240, math.max(120, math.min(list.AbsoluteContentSize.Y + 18, h - 132 - 16)))
end
list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
local function setOpen(open)
	fit()
	panel.Visible = open
	openBtn.Modal = open
	if open then UserInputService.MouseBehavior = Enum.MouseBehavior.Default end
end
openBtn.MouseButton1Click:Connect(function() setOpen(not panel.Visible) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.P then setOpen(not panel.Visible) end
end)
