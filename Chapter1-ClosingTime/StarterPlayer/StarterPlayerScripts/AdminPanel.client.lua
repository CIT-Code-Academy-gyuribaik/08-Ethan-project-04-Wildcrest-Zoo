-- ADMIN PANEL: only the game's owner sees it (the server checks every command again).
-- [P] opens it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local isOwner = RunService:IsStudio() or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
if not isOwner then
	return
end
local remotes = ReplicatedStorage:WaitForChild("ZooRemotes")
local Admin = remotes:WaitForChild("Admin")
local ch2 = workspace:FindFirstChild("CrashSite") ~= nil

local gui = Instance.new("ScreenGui")
gui.Name = "AdminPanel"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local ACCENT = Color3.fromRGB(255, 190, 80)
local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 6)
	c.Parent = o
end

local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.fromOffset(110, 26)
openBtn.Position = UDim2.new(1, -126, 0, 300)
openBtn.BackgroundColor3 = Color3.fromRGB(30, 22, 12)
openBtn.TextColor3 = ACCENT
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 13
openBtn.Text = "ADMIN [P]"
openBtn.Parent = gui
corner(openBtn)

local panel = Instance.new("ScrollingFrame")
panel.Size = UDim2.fromOffset(230, 300)
panel.Position = UDim2.new(1, -246, 0, 332)
panel.CanvasSize = UDim2.new()
panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
panel.ScrollingDirection = Enum.ScrollingDirection.Y
panel.ScrollBarThickness = 5
panel.ScrollBarImageColor3 = Color3.fromRGB(255, 190, 80)
panel.BorderSizePixel = 0
panel.BackgroundColor3 = Color3.fromRGB(16, 14, 12)
panel.BackgroundTransparency = 0.08
panel.Visible = false
panel.Parent = gui
corner(panel, 8)
local stroke = Instance.new("UIStroke")
stroke.Color = ACCENT
stroke.Transparency = 0.5
stroke.Parent = panel
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 14)
pad.Parent = panel
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 5)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel

local order = 0
local function header(text)
	order += 1
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 18)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextSize = 12
	l.TextColor3 = ACCENT
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.LayoutOrder = order
	l.Parent = panel
end
local function button(text, onClick)
	order += 1
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 28)
	b.BackgroundColor3 = Color3.fromRGB(38, 34, 30)
	b.TextColor3 = Color3.fromRGB(235, 230, 220)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Text = "   " .. text
	b.AutoButtonColor = true
	b.LayoutOrder = order
	b.Parent = panel
	corner(b, 5)
	b.MouseButton1Click:Connect(function()
		onClick(b)
	end)
	return b
end
local function toggle(text, onChange)
	local on = false
	local b
	local pill = Instance.new("TextLabel")
	b = button(text, function()
		on = not on
		pill.Text = on and "ON" or "OFF"
		pill.BackgroundColor3 = on and Color3.fromRGB(90, 200, 110) or Color3.fromRGB(80, 70, 65)
		onChange(on)
	end)
	pill.Size = UDim2.fromOffset(40, 18)
	pill.AnchorPoint = Vector2.new(1, 0.5)
	pill.Position = UDim2.new(1, -6, 0.5, 0)
	pill.BackgroundColor3 = Color3.fromRGB(80, 70, 65)
	pill.Font = Enum.Font.GothamBlack
	pill.TextSize = 11
	pill.TextColor3 = Color3.new(1, 1, 1)
	pill.Text = "OFF"
	pill.Parent = b
	corner(pill, 9)
	return b
end
local function send(cmd, value)
	Admin:FireServer(cmd, value)
end
local function myRoot()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
local function teleport(pos)
	local r = myRoot()
	if r and pos then
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
	end
end

-- Fly (noclip): WASD + camera direction, Space up, Ctrl down
local flying = false
local flyConn, vel, gyro
local savedCollide = {}
local function setFly(on)
	flying = on
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local r = myRoot()
	if flyConn then
		flyConn:Disconnect()
		flyConn = nil
	end
	if vel then
		vel:Destroy()
		vel = nil
	end
	if gyro then
		gyro:Destroy()
		gyro = nil
	end
	for part, cc in savedCollide do
		if part.Parent then
			part.CanCollide = cc
		end
	end
	table.clear(savedCollide)
	if hum then
		hum.PlatformStand = false
	end
	if not on or not r or not hum then
		return
	end
	hum.PlatformStand = true
	vel = Instance.new("BodyVelocity")
	vel.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	vel.Velocity = Vector3.zero
	vel.Parent = r
	gyro = Instance.new("BodyGyro")
	gyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
	gyro.P = 2e4
	gyro.Parent = r
	flyConn = RunService.Stepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not r.Parent then
			setFly(false)
			return
		end
		for _, p in char:GetDescendants() do
			if p:IsA("BasePart") and p.CanCollide then
				savedCollide[p] = true
				p.CanCollide = false
			end
		end
		local move = hum.MoveDirection
		local look = cam.CFrame.LookVector
		local dir = Vector3.zero
		if move.Magnitude > 0.05 then
			-- follow the camera's pitch when moving forward/back
			local flatLook = Vector3.new(look.X, 0, look.Z).Unit
			local fwd = move:Dot(flatLook)
			dir = move + Vector3.new(0, look.Y * fwd, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			dir += Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			dir -= Vector3.new(0, 1, 0)
		end
		local speed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 120 or 55
		vel.Velocity = dir.Magnitude > 0 and dir.Unit * speed or Vector3.zero
		gyro.CFrame = CFrame.lookAt(r.Position, r.Position + Vector3.new(look.X, 0, look.Z))
	end)
end
player.CharacterAdded:Connect(function()
	flying = false
	flyConn = flyConn and flyConn:Disconnect() or nil
	table.clear(savedCollide)
end)

header("PLAYER")
toggle("God Mode", function(on)
	send("god", on)
end)
toggle("Fly + No-clip", setFly)
toggle("Speed x2", function(on)
	player:SetAttribute("AdminSpeed", on and 2 or nil)
end)
button("Refill items + flashlight", function()
	send("refill")
end)
button("+$1000", function()
	send("cash")
end)

header("MONSTERS")
toggle("Freeze monsters", function(on)
	send("freeze", on)
end)
button("Remove all monsters", function()
	send("clear")
end)

header("TELEPORT")
button("To the objective marker", function()
	local bb = player.PlayerGui:FindFirstChild("ObjectiveMarker")
	local part = bb and bb.Adornee
	if part and part:IsA("BasePart") then
		teleport(part.Position + Vector3.new(4, 0, 0))
	end
end)
button("To the start", function()
	local s = workspace:FindFirstChild("Start", true)
	if s then
		teleport(s.Position)
	end
end)
if ch2 then
	button("To the cage", function()
		local c = workspace:FindFirstChild("CaptureCage", true)
		local lever = c and c:FindFirstChild("Lever")
		if lever then
			teleport(lever:GetPivot().Position + Vector3.new(0, 0, -6))
		end
	end)
end

header(ch2 and "CHAPTER 2" or "CHAPTER 1")
button("Power ON", function()
	send("power")
end)
if ch2 then
	button("Skip capture (go to the van)", function()
		send("skipCapture")
	end)
	button("Skip to the boss fight", function()
		send("boss")
	end)
	button("Hurt B-00 (-25)", function()
		send("hurt")
	end)
	button("WIN (kill B-00)", function()
		send("win")
	end)
else
	button("Give all samples", function()
		send("samples")
	end)
	button("WIN (escape now)", function()
		send("win")
	end)
end

-- as tall as the content, but never past the bottom of the screen (then it scrolls)
local function fit()
	local screenH = workspace.CurrentCamera.ViewportSize.Y
	local want = list.AbsoluteContentSize.Y + 18
	panel.Size = UDim2.fromOffset(230, math.max(120, math.min(want, screenH - 332 - 16)))
end
list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
local function setOpen(open)
	fit()
	panel.Visible = open
	openBtn.BackgroundColor3 = open and Color3.fromRGB(70, 50, 20) or Color3.fromRGB(30, 22, 12)
	-- free the mouse while the panel is open
	UserInputService.MouseBehavior = open and Enum.MouseBehavior.Default or UserInputService.MouseBehavior
	openBtn.Modal = open
end
openBtn.MouseButton1Click:Connect(function()
	setOpen(not panel.Visible)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.P then
		setOpen(not panel.Visible)
	end
end)
