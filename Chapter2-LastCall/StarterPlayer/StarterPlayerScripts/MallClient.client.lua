-- Closing Time - Chapter 2: Last Call client (the mall): first person, flashlight,
-- sprint, dash, flares, HUD, hiding, notes, 3D jumpscares, roar shake, cage timer,
-- radar, shop, difficulty picker, and the van getaway ending.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("ZooConfig"))
local remotes = ReplicatedStorage:WaitForChild("ZooRemotes")
local views = ReplicatedStorage:WaitForChild("MonsterViews")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local level = workspace:WaitForChild("Zoo") -- the mall

local battery = Config.BatteryMax
local stamina = Config.StaminaMax
local flashlightOn = true
local sprintHeld = false
local shakeAmount, shakeUntil = 0, 0
local introPlaying = false

player.CameraMode = Enum.CameraMode.LockFirstPerson

local alarmTint = Instance.new("ColorCorrectionEffect")
alarmTint.Name = "AlarmTint"
alarmTint.Enabled = false
alarmTint.Parent = Lighting

-- GUI ---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ZooHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.SpecialElite
	l.TextColor3 = Color3.fromRGB(230, 225, 210)
	l.TextStrokeTransparency = 0.5
	for k, v in props do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local objective = label(gui, { Size = UDim2.new(0.5, 0, 0, 60), Position = UDim2.fromOffset(20, 50), TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, TextSize = 22, Text = "" })
local livesLabel = label(gui, { Size = UDim2.fromOffset(200, 34), Position = UDim2.new(1, -220, 0, 50), TextXAlignment = Enum.TextXAlignment.Right,
	TextSize = 26, TextColor3 = Color3.fromRGB(255, 90, 90), Text = "" })
local carryLabel = label(gui, { Size = UDim2.fromOffset(300, 28), Position = UDim2.new(1, -320, 0, 86), TextXAlignment = Enum.TextXAlignment.Right,
	TextSize = 20, TextColor3 = Color3.fromRGB(255, 140, 130), Text = "" })
local center = label(gui, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromScale(0, 0.72), TextSize = 26, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })
local hideHint = label(gui, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromScale(0, 0.82), TextSize = 22, Text = "", TextColor3 = Color3.fromRGB(180, 200, 255) })
local cageTimer = label(gui, { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromScale(0, 0.1), TextSize = 34, Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.fromRGB(255, 80, 60), Text = "" })
local dot = Instance.new("Frame")
dot.Size = UDim2.fromOffset(4, 4)
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.BackgroundColor3 = Color3.new(1, 1, 1)
dot.BackgroundTransparency = 0.4
dot.BorderSizePixel = 0
dot.Parent = gui
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

local function bar(y, color, title)
	local back = Instance.new("Frame")
	back.Size = UDim2.fromOffset(220, 12)
	back.Position = UDim2.new(0, 20, 1, y)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	back.BackgroundTransparency = 0.3
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	label(back, { Size = UDim2.new(0, 160, 0, 18), Position = UDim2.fromOffset(0, -20), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, Text = title })
	return fill
end
local batteryFill = bar(-70, Color3.fromRGB(240, 210, 80), "FLASHLIGHT [F]")
local staminaFill = bar(-34, Color3.fromRGB(120, 200, 255), "STAMINA [SHIFT]")

-- red danger edges
local edges = {}
for i, cfg in { { UDim2.new(1, 0, 0.18, 0), UDim2.new(0, 0, 0, 0), 90 }, { UDim2.new(1, 0, 0.18, 0), UDim2.new(0, 0, 0.82, 0), 270 },
	{ UDim2.new(0.14, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0 }, { UDim2.new(0.14, 0, 1, 0), UDim2.new(0.86, 0, 0, 0), 180 } } do
	local f = Instance.new("Frame")
	f.Size = cfg[1]
	f.Position = cfg[2]
	f.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	local g = Instance.new("UIGradient")
	g.Rotation = cfg[3]
	g.Transparency = NumberSequence.new(0, 1)
	g.Parent = f
	f.Parent = gui
	edges[i] = f
end

local function mbtn(text, pos, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(90, 50)
	b.Position = pos
	b.BackgroundColor3 = color or Color3.fromRGB(30, 30, 36)
	b.BackgroundTransparency = 0.3
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.Text = text
	b.Parent = gui
	Instance.new("UICorner", b)
	return b
end
local touch = UserInputService.TouchEnabled
if touch then
	local lightBtn = mbtn("LIGHT", UDim2.new(1, -200, 1, -210))
	local sprintBtn = mbtn("SPRINT", UDim2.new(1, -200, 1, -150))
	lightBtn.Activated:Connect(function()
		flashlightOn = not flashlightOn
	end)
	sprintBtn.Activated:Connect(function()
		sprintHeld = not sprintHeld
		sprintBtn.BackgroundColor3 = sprintHeld and Color3.fromRGB(40, 90, 140) or Color3.fromRGB(30, 30, 36)
	end)
end

local overlay = Instance.new("ScreenGui")
overlay.Name = "ZooOverlay"
overlay.ResetOnSpawn = false
overlay.IgnoreGuiInset = true
overlay.DisplayOrder = 20
overlay.Parent = player.PlayerGui

-- Note reader
local notePaper = Instance.new("Frame")
notePaper.AnchorPoint = Vector2.new(0.5, 0.5)
notePaper.Position = UDim2.fromScale(0.5, 0.5)
notePaper.Size = UDim2.fromOffset(460, 400)
notePaper.BackgroundColor3 = Color3.fromRGB(235, 228, 205)
notePaper.Visible = false
notePaper.Parent = overlay
Instance.new("UICorner", notePaper).CornerRadius = UDim.new(0, 4)
local noteText = label(notePaper, { Size = UDim2.new(1, -40, 1, -80), Position = UDim2.fromOffset(20, 20), TextColor3 = Color3.fromRGB(35, 30, 25),
	TextStrokeTransparency = 1, TextWrapped = true, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
Instance.new("UITextSizeConstraint", noteText).MaxTextSize = 22
local closeNote = Instance.new("TextButton")
closeNote.Size = UDim2.fromOffset(160, 40)
closeNote.Position = UDim2.new(0.5, -80, 1, -55)
closeNote.BackgroundColor3 = Color3.fromRGB(60, 50, 40)
closeNote.TextColor3 = Color3.new(1, 1, 1)
closeNote.Font = Enum.Font.SpecialElite
closeNote.TextSize = 20
closeNote.Text = "Put it down"
closeNote.Modal = true
closeNote.Parent = notePaper
closeNote.Activated:Connect(function()
	notePaper.Visible = false
end)
remotes:WaitForChild("ShowNote").OnClientEvent:Connect(function(text)
	noteText.Text = text
	notePaper.Visible = true
end)

local noticeId = 0
local function notice(text, color, secs)
	noticeId += 1
	local id = noticeId
	center.Text = text
	center.TextColor3 = color or Color3.fromRGB(230, 225, 210)
	center.TextTransparency = 0
	center.TextStrokeTransparency = 0.5
	task.delay(secs or 3.5, function()
		if id == noticeId then
			TweenService:Create(center, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end
remotes:WaitForChild("Notify").OnClientEvent:Connect(notice)
remotes:WaitForChild("AddBattery").OnClientEvent:Connect(function(amount)
	battery = math.min(Config.BatteryMax, battery + amount)
	notice("+ Battery", nil, 1.5)
end)

-- Roars / ground slams shake the screen
remotes:WaitForChild("Roar").OnClientEvent:Connect(function(strength)
	strength = tonumber(strength) or 1
	shakeAmount = math.max(shakeAmount, strength)
	shakeUntil = os.clock() + 0.6 + strength * 0.9
end)

-- Sounds ---------------------------------------------------------------------------
local function sound(id, volume, pitch)
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 1
	s.PlaybackSpeed = pitch or 1
	s.Parent = gui
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end
local function loopSound(id, vol)
	local s = Instance.new("Sound")
	s.SoundId = id or ""
	s.Looped = true
	s.Volume = vol or 0
	s.Parent = gui
	if id and id ~= "" then
		s:Play()
	end
	return s
end
local ambience = loopSound(Config.Sounds.Ambience, 0.5)
local heartbeat = loopSound(Config.Sounds.Heartbeat)
local alarmSound = loopSound(Config.Sounds.Alarm)

-- Jumpscare: the actual monster lunges at the screen -----------------------------------
local scared = false
remotes:WaitForChild("Caught").OnClientEvent:Connect(function(kind, livesLeft)
	scared = true
	notePaper.Visible = false
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.new(0, 0, 0)
	root.BorderSizePixel = 0
	root.Parent = overlay
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromScale(1.1, 1.1)
	vp.AnchorPoint = Vector2.new(0.5, 0.5)
	vp.Position = UDim2.fromScale(0.5, 0.5)
	vp.BackgroundColor3 = Color3.new(0, 0, 0)
	vp.Ambient = Color3.fromRGB(150, 125, 125)
	vp.LightColor = Color3.fromRGB(255, 230, 220)
	vp.LightDirection = Vector3.new(0, 1, -0.3)
	vp.Parent = root
	local template = views:FindFirstChild(kind)
	local vcam = Instance.new("Camera")
	vcam.FieldOfView = 60
	vcam.Parent = vp
	vp.CurrentCamera = vcam
	local face, look, height = Vector3.zero, Vector3.new(0, 0, -1), 5
	if template then
		local m = template:Clone()
		m:PivotTo(CFrame.new(0, m:GetAttribute("HipHeight") or 3, 0))
		m.Parent = vp
		local cf, size = m:GetBoundingBox()
		height = size.Y
		look = m.PrimaryPart.CFrame.LookVector
		face = cf.Position + Vector3.new(0, size.Y * 0.32, 0) + look * (math.max(size.X, size.Z) * 0.3)
	end
	local tint = Instance.new("Frame")
	tint.Size = UDim2.fromScale(1, 1)
	tint.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
	tint.BackgroundTransparency = 0.75
	tint.BorderSizePixel = 0
	tint.ZIndex = 3
	tint.Parent = root
	sound(Config.Sounds.Jumpscare, 2.5)
	local far, near = math.max(8, height * 0.9), math.max(1.5, height * 0.12)
	local t0 = os.clock()
	while os.clock() - t0 < 1.4 do
		local t = math.clamp((os.clock() - t0) / 0.25, 0, 1)
		local dist = far + (near - far) * (1 - (1 - t) ^ 3)
		local shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * (0.15 + t * 0.35)
		vcam.CFrame = CFrame.lookAt(face + look * dist + shake, face)
		vp.Position = UDim2.new(0.5, math.random(-12, 12), 0.5, math.random(-12, 12))
		tint.BackgroundTransparency = 0.6 + math.random() * 0.3
		RunService.RenderStepped:Wait()
	end
	vp.Visible = false
	tint.Visible = false
	local msg = label(root, { Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromScale(0, 0.45), TextSize = 40, TextColor3 = Color3.fromRGB(200, 40, 40),
		Text = livesLeft < 0 and ((ReplicatedStorage:GetAttribute("ZooPhase") or 0) >= 6 and "Infinite Lives - you come to by the wreck" or "Infinite Lives - you wake up by the van") or livesLeft > 0 and ("Lives left: " .. livesLeft) or "You were taken..." })
	task.wait(1.6)
	TweenService:Create(root, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(msg, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.wait(0.8)
	root:Destroy()
	scared = false
end)

-- FINALE ---------------------------------------------------------------------------------------
-- The ride: you sit in the van's cargo hold next to the cage...
local rideScene, rideMon, rideMonHome, rideRumble
local chokeRunning, chokeAbort = false, false
local function rideCleanup()
	if rideScene then
		rideScene:Destroy()
		rideScene, rideMon = nil, nil
	end
	if rideRumble then
		rideRumble:Destroy()
		rideRumble = nil
	end
end
local function buildRide()
	if rideScene then
		return
	end
	local t = ReplicatedStorage:FindFirstChild("VanInterior")
	rideScene = t:Clone()
	rideScene:PivotTo(CFrame.new(0, 600, 3000))
	rideScene.Parent = workspace
	-- road rumble (the ambience pitched way down)
	if Config.Sounds.Ambience and Config.Sounds.Ambience ~= "" then
		rideRumble = Instance.new("Sound")
		rideRumble.SoundId = Config.Sounds.Ambience
		rideRumble.Looped = true
		rideRumble.Volume = 0.9
		rideRumble.PlaybackSpeed = 0.42
		rideRumble.Parent = gui
		rideRumble:Play()
	end
	local v = views:FindFirstChild("Behemoth")
	if v then
		rideMon = v:Clone()
		pcall(function()
			rideMon:ScaleTo(0.42)
		end)
		local spot = rideScene.MonsterSpot.CFrame
		rideMon:PivotTo(spot)
		local cf, size = rideMon:GetBoundingBox()
		rideMon:PivotTo(spot + Vector3.new(0, (spot.Position.Y - (cf.Position.Y - size.Y / 2)), 0))
		rideMonHome = rideMon:GetPivot()
		rideMon.Parent = rideScene
	end
	gui.Enabled = false
	notePaper.Visible = false
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 75
end
local chokeUI = Instance.new("Frame")
chokeUI.Size = UDim2.fromScale(1, 1)
chokeUI.BackgroundTransparency = 1
chokeUI.Visible = false
chokeUI.ZIndex = 30
chokeUI.Parent = overlay
local blackout = Instance.new("Frame")
blackout.Size = UDim2.fromScale(1, 1)
blackout.BackgroundColor3 = Color3.new(0, 0, 0)
blackout.BackgroundTransparency = 1
blackout.BorderSizePixel = 0
blackout.ZIndex = 30
blackout.Parent = chokeUI
local redEdge = Instance.new("Frame")
redEdge.Size = UDim2.fromScale(1, 1)
redEdge.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
redEdge.BackgroundTransparency = 0.6
redEdge.BorderSizePixel = 0
redEdge.ZIndex = 31
redEdge.Parent = chokeUI
local rg = Instance.new("UIGradient")
rg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0) })
rg.Parent = redEdge
local chokeTitle = label(chokeUI, { Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromScale(0, 0.62), Font = Enum.Font.Creepster, TextScaled = true,
	TextColor3 = Color3.fromRGB(255, 70, 60), Text = "IT'S GOT YOUR THROAT!", ZIndex = 33 })
local chokeHint = label(chokeUI, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromScale(0, 0.7), TextSize = 26, Font = Enum.Font.GothamBlack,
	Text = "MASH [SPACE] / CLICK / TAP TO BREAK FREE", ZIndex = 33 })
local chokeBack = Instance.new("Frame")
chokeBack.Size = UDim2.new(0.5, 0, 0, 26)
chokeBack.Position = UDim2.fromScale(0.25, 0.77)
chokeBack.BackgroundColor3 = Color3.fromRGB(25, 10, 10)
chokeBack.BorderSizePixel = 0
chokeBack.ZIndex = 33
chokeBack.Parent = chokeUI
Instance.new("UICorner", chokeBack)
local chokeFill = Instance.new("Frame")
chokeFill.Size = UDim2.fromScale(0.25, 1)
chokeFill.BackgroundColor3 = Color3.fromRGB(255, 220, 90)
chokeFill.BorderSizePixel = 0
chokeFill.ZIndex = 34
chokeFill.Parent = chokeBack
Instance.new("UICorner", chokeFill)
local subtitle = label(overlay, { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromScale(0, 0.86), TextSize = 26, Text = "", ZIndex = 35 })
local tapBtn -- big invisible button so phone taps count (and the mouse is free)
tapBtn = Instance.new("TextButton")
tapBtn.Size = UDim2.fromScale(1, 1)
tapBtn.BackgroundTransparency = 1
tapBtn.Text = ""
tapBtn.ZIndex = 40
tapBtn.Modal = true
tapBtn.Visible = false
tapBtn.Parent = overlay

local function rideCam(t, seat, shake)
	shake = shake or 1
	camera.CFrame = seat * CFrame.new(math.sin(t * 9) * 0.03 * shake, math.sin(t * 13) * 0.04 * shake, 0)
		* CFrame.Angles(math.sin(t * 1.3) * 0.04 * shake, math.sin(t * 0.7) * 0.12, math.sin(t * 2.1) * 0.02 * shake)
end

local function runChoke(firstTime)
	chokeRunning, chokeAbort = true, false
	buildRide()
	local seat = rideScene.Seat.CFrame
	local dome = rideScene:FindFirstChild("DomeLight")
	local domeLight = dome and dome:FindFirstChild("Light")
	local t0 = os.clock()
	local calm = firstTime and 7 or 1.5
	local lines = firstTime and {
		{ 0.5, "The cage is winched in. Wildcrest HQ is an hour away." },
		{ 3.2, "B-00 hasn't moved since you left the mall..." },
		{ 5.6, "...it's breathing faster." },
	} or {}
	if not firstTime then
		subtitle.Text = "You come to... it's still got you!"
	end
	if rideMon then
		rideMon:PivotTo(rideMonHome)
	end
	while os.clock() - t0 < calm and not chokeAbort do
		local t = os.clock() - t0
		for i = #lines, 1, -1 do
			if t >= lines[i][1] then
				subtitle.Text = lines[i][2]
				table.remove(lines, i)
			end
		end
		rideCam(t, seat)
		if domeLight then
			domeLight.Brightness = (t > calm - 2 and math.random() < 0.3) and 0.2 or 1.6
		end
		if rideMon and t > calm - 1.5 then
			-- it slowly turns its head toward you
			rideMon:PivotTo(rideMonHome * CFrame.new(0, 0, -0.3 * (t - (calm - 1.5))))
		end
		RunService.RenderStepped:Wait()
	end
	subtitle.Text = ""
	if chokeAbort then
		chokeRunning = false
		return
	end
	-- it LUNGES through the bars
	sound(Config.Sounds.Jumpscare, 2.2)
	sound(Config.MonsterSounds.Behemoth.Id, 3, 0.8)
	shakeAmount, shakeUntil = 1, os.clock() + 1
	chokeUI.Visible = true
	tapBtn.Visible = true
	local progress = 25
	local limit = Config.ChokeTime or 9
	local function press()
		progress += Config.ChokePerPress or 7
		chokeFill.BackgroundColor3 = Color3.fromRGB(255, 255, 160)
	end
	local c1 = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			press()
		end
	end)
	local c2 = tapBtn.MouseButton1Down:Connect(press)
	local start = os.clock()
	local result
	local barsX = seat.Position:Lerp(rideMonHome.Position, 0.55)
	local lunge = CFrame.lookAt(Vector3.new(barsX.X, rideMonHome.Position.Y, seat.Position.Z), Vector3.new(seat.Position.X, rideMonHome.Position.Y, seat.Position.Z))
	while true do
		local dt = RunService.RenderStepped:Wait()
		if chokeAbort then
			break
		end
		local e = os.clock() - start
		progress = math.max(0, progress - (Config.ChokeDecay or 15) * dt * (1 + e / limit))
		chokeFill.Size = UDim2.fromScale(math.clamp(progress / 100, 0, 1), 1)
		chokeFill.BackgroundColor3 = chokeFill.BackgroundColor3:Lerp(Color3.fromRGB(255, 200, 80), dt * 8)
		local dark = math.clamp(e / limit, 0, 1)
		blackout.BackgroundTransparency = 1 - dark * 0.9
		redEdge.BackgroundTransparency = 0.6 - 0.3 * math.abs(math.sin(e * 6))
		if rideMon then
			local face = rideMon:GetPivot()
			rideMon:PivotTo(face:Lerp(lunge * CFrame.Angles(0, math.rad(180), 0), math.min(1, dt * 10)))
		end
		-- dragged against the bars, face to face with it
		local pulled = seat.Position:Lerp(barsX, 0.45) + Vector3.new(0, -0.4, 0)
		local look = (rideMon and rideMon:GetBoundingBox().Position or barsX) + Vector3.new(0, 1.2, 0)
		local struggle = math.clamp(progress / 100, 0, 1)
		camera.CFrame = CFrame.lookAt(pulled, look) * CFrame.Angles((math.random() - 0.5) * 0.08, (math.random() - 0.5) * 0.08 + math.sin(e * 20) * 0.04 * struggle, (math.random() - 0.5) * 0.1)
		if progress >= 100 then
			result = true
			break
		end
		if e >= limit then
			result = false
			break
		end
	end
	c1:Disconnect()
	c2:Disconnect()
	tapBtn.Visible = false
	chokeUI.Visible = false
	if chokeAbort then
		chokeRunning = false
		return
	end
	if result then
		subtitle.Text = "You rip its claw off your throat and SLAM it back into the cage!"
		sound(Config.MonsterSounds.Behemoth.Id, 3, 0.6)
		shakeAmount, shakeUntil = 1, os.clock() + 0.6
		if rideMon then
			rideMon:PivotTo(rideMonHome)
		end
	else
		blackout.BackgroundTransparency = 0
		chokeUI.Visible = true
		chokeTitle.Text = "YOU BLACKED OUT..."
		chokeHint.Text = ""
		chokeBack.Visible = false
		task.delay(2.3, function()
			chokeUI.Visible = false
			chokeTitle.Text = "IT'S GOT YOUR THROAT!"
			chokeHint.Text = "MASH [SPACE] / CLICK / TAP TO BREAK FREE"
			chokeBack.Visible = true
			blackout.BackgroundTransparency = 1
		end)
	end
	remotes.Choke:FireServer(result)
	chokeRunning = false
end
remotes:WaitForChild("Choke").OnClientEvent:Connect(function(what, firstTime)
	if what == "start" and not chokeRunning then
		task.spawn(runChoke, firstTime == true)
	end
end)

-- The crash: the van swerves, rolls, and the cage breaks open
remotes:WaitForChild("Crash").OnClientEvent:Connect(function()
	chokeAbort = true
	task.wait()
	buildRide()
	chokeUI.Visible = false
	tapBtn.Visible = false
	local seat = rideScene.Seat.CFrame
	local center = rideScene:GetPivot().Position + Vector3.new(0, 4, 0)
	local fade = Instance.new("Frame")
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(1, 1, 1)
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.ZIndex = 45
	fade.Parent = overlay
	subtitle.Text = "\"WHAT'S GOING ON BACK THERE?!\" - the driver swerves"
	sound(Config.Sounds.Alarm, 1, 0.5)
	local t0 = os.clock()
	while os.clock() - t0 < 3.4 do
		local t = os.clock() - t0
		if t < 1.2 then
			-- swerving
			rideCam(t * 3, seat * CFrame.Angles(0, 0, math.sin(t * 8) * 0.25), 4)
		else
			-- rolling over
			local k = math.clamp((t - 1.2) / 1.6, 0, 1)
			if not fade:GetAttribute("Boom") then
				fade:SetAttribute("Boom", true)
				sound(Config.Sounds.Jumpscare, 1.5, 0.5)
				sound(Config.MonsterSounds.Behemoth.Id, 3, 0.55)
			end
			local roll = CFrame.new(center) * CFrame.Angles(0, 0, k * math.pi * 2.2) * CFrame.new(-center) * seat
			camera.CFrame = roll * CFrame.Angles((math.random() - 0.5) * 0.3, (math.random() - 0.5) * 0.3, 0)
			if rideMon then
				rideMon:PivotTo(CFrame.new(center) * CFrame.Angles(0, 0, k * math.pi * 2.6) * CFrame.new(-center) * rideMonHome)
			end
			if t > 2.6 then
				fade.BackgroundColor3 = Color3.new(0, 0, 0)
				fade.BackgroundTransparency = math.max(0, 1 - (t - 2.6) * 2)
			end
		end
		RunService.RenderStepped:Wait()
	end
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 0
	subtitle.Text = ""
	task.wait(1)
	rideCleanup()
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	gui.Enabled = true
	task.wait(0.4)
	TweenService:Create(fade, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
	notice("The cage burst open in the crash. B-00 is LOOSE. KILL IT.", Color3.fromRGB(255, 70, 60), 5)
	task.delay(2, function()
		fade:Destroy()
	end)
end)

-- Boss HP bar
do
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0.4, 0, 0, 22)
	holder.Position = UDim2.new(0.3, 0, 0, 30)
	holder.BackgroundColor3 = Color3.fromRGB(25, 8, 8)
	holder.BorderSizePixel = 0
	holder.Visible = false
	holder.Parent = gui
	Instance.new("UICorner", holder)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
	fill.BorderSizePixel = 0
	fill.Parent = holder
	Instance.new("UICorner", fill)
	local bossName = label(holder, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, -24), Font = Enum.Font.Creepster, TextSize = 24, Text = "B-00" })
	local function refresh()
		local hp = ReplicatedStorage:GetAttribute("BossHP") or 0
		local max = ReplicatedStorage:GetAttribute("BossMaxHP") or 100
		local enraged = hp > 0 and hp <= max * 0.5
		bossName.Text = enraged and "B-00 - ENRAGED" or "B-00"
		bossName.TextColor3 = enraged and Color3.fromRGB(255, 120, 60) or Color3.fromRGB(230, 225, 210)
		fill.BackgroundColor3 = enraged and Color3.fromRGB(240, 90, 30) or Color3.fromRGB(200, 30, 30)
		holder.Visible = (ReplicatedStorage:GetAttribute("ZooPhase") or 0) >= 6 and hp > 0
		TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1) }):Play()
	end
	ReplicatedStorage:GetAttributeChangedSignal("BossHP"):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal("ZooPhase"):Connect(refresh)
	refresh()
end

-- The ending: dawn over the wreck, B-00 dead on the road
local function playEnding()
	local pos = ReplicatedStorage:GetAttribute("BossDeathPos")
	if typeof(pos) ~= "Vector3" then
		return
	end
	gui.Enabled = false
	local saved = { ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
	local fade = Instance.new("Frame")
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BorderSizePixel = 0
	fade.ZIndex = 10
	fade.Parent = overlay
	local dead
	local v = views:FindFirstChild("Behemoth")
	if v then
		dead = v:Clone()
		local sc = Config.BehemothScale or 1
		if sc ~= 1 then
			dead:ScaleTo(dead:GetScale() * sc)
		end
		local hip = (dead:GetAttribute("HipHeight") or 8) * sc
		local yaw = ReplicatedStorage:GetAttribute("BossDeathYaw") or 0
		dead:PivotTo(CFrame.new(pos + Vector3.new(0, hip * 0.45, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(88)))
		dead.Parent = workspace
	end
	Lighting.ClockTime = 6.6
	Lighting.Brightness = 1.8
	Lighting.Ambient = Color3.fromRGB(80, 65, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 130, 120)
	-- a warm, hazy sunrise
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	local mood = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local savedFx = {}
	if atm then
		savedFx.atm = { Color = atm.Color, Decay = atm.Decay, Density = atm.Density, Haze = atm.Haze }
		atm.Color = Color3.fromRGB(255, 175, 130)
		atm.Decay = Color3.fromRGB(190, 110, 90)
		atm.Density = 0.3
		atm.Haze = 1.6
	end
	if mood then
		savedFx.mood = { TintColor = mood.TintColor, Brightness = mood.Brightness }
		mood.TintColor = Color3.fromRGB(255, 225, 200)
		mood.Brightness = 0.04
	end
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(fade, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
	local lines = {
		{ 1, "Dawn. The fire is still burning." },
		{ 3.5, "Subject B-00 is dead." },
		{ 6, "Somewhere, Wildcrest Corp. is already opening the next cage..." },
	}
	local t0 = os.clock()
	while os.clock() - t0 < 8.5 do
		local t = os.clock() - t0
		for i = #lines, 1, -1 do
			if t >= lines[i][1] then
				subtitle.Text = lines[i][2]
				table.remove(lines, i)
			end
		end
		local ang = t * 0.18
		camera.CFrame = CFrame.lookAt(pos + Vector3.new(math.cos(ang) * 30, 9 - t * 0.3, math.sin(ang) * 30), pos + Vector3.new(0, 3, 0))
		if t > 7.6 and fade.BackgroundTransparency >= 1 then
			TweenService:Create(fade, TweenInfo.new(0.8), { BackgroundTransparency = 0 }):Play()
		end
		RunService.Heartbeat:Wait()
	end
	subtitle.Text = ""
	for k, val in saved do
		Lighting[k] = val
	end
	for k, val in (savedFx.atm or {}) do
		atm[k] = val
	end
	for k, val in (savedFx.mood or {}) do
		mood[k] = val
	end
	if dead then
		dead:Destroy()
	end
	task.delay(6, function()
		fade:Destroy()
	end)
end

remotes:WaitForChild("Escaped").OnClientEvent:Connect(function(secs, _, _, difficulty, reward, mvpText)
	local ok, err = pcall(playEnding)
	if not ok then
		warn("Ending cutscene error: " .. tostring(err))
	end
	camera.CameraType = Enum.CameraType.Scriptable
	print("Escape cutscene finished")
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.new(0, 0, 0)
	root.ZIndex = 11
	root.Parent = overlay
	local function txt(props)
		local l = label(root, props)
		l.ZIndex = 12
		return l
	end
	txt({ Size = UDim2.new(1, 0, 0, 90), Position = UDim2.fromScale(0, 0.35), Font = Enum.Font.Creepster, TextScaled = true,
		TextColor3 = Color3.fromRGB(120, 255, 140), Text = "B-00 IS DEAD" })
	txt({ Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromScale(0, 0.5), TextSize = 26,
		Text = ("Time: %d:%02d   Difficulty: %s   Reward: $%d"):format(secs // 60, secs % 60, string.upper(difficulty or "Normal"), reward or 0) })
	txt({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromScale(0, 0.58), TextSize = 20, TextColor3 = Color3.fromRGB(170, 170, 170),
		Text = "CHAPTER 2: LAST CALL - COMPLETE" })
	if mvpText then
		txt({ Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromScale(0, 0.64), TextSize = 22, Font = Enum.Font.GothamBlack,
			TextColor3 = Color3.fromRGB(255, 210, 110), Text = mvpText })
	end
	task.delay(6, function()
		root:Destroy()
		gui.Enabled = true
		camera.CameraType = Enum.CameraType.Custom
	end)
end)

-- Flashlight --------------------------------------------------------------------------
local beamPart = Instance.new("Part")
beamPart.Name = "FlashlightBeam"
beamPart.Size = Vector3.new(0.2, 0.2, 0.2)
beamPart.Transparency = 1
beamPart.Anchored = true
beamPart.CanCollide = false
beamPart.CanQuery = false
beamPart.CanTouch = false
beamPart.CastShadow = false
local spot = Instance.new("SpotLight")
spot.Face = Enum.NormalId.Front
spot.Range = 60
spot.Angle = 50
spot.Brightness = 3.5
spot.Color = Color3.fromRGB(255, 245, 225)
spot.Shadows = true
spot.Parent = beamPart
local glow = Instance.new("PointLight")
glow.Range = 7
glow.Brightness = 0.35
glow.Color = Color3.fromRGB(255, 245, 225)
glow.Parent = beamPart
beamPart.Parent = camera

-- Abilities: flares [G] + dash [C] ---------------------------------------------------------
local abilityLabel = label(gui, { Size = UDim2.fromOffset(320, 20), Position = UDim2.new(0, 20, 1, -130), TextXAlignment = Enum.TextXAlignment.Left,
	TextSize = 16, Text = "", TextColor3 = Color3.fromRGB(255, 170, 120) })
local lastFlare = 0
local function throwFlare()
	if player:GetAttribute("Hidden") or not gui.Enabled then
		return
	end
	if (player:GetAttribute("Flares") or 0) <= 0 then
		notice("No flares left.", nil, 1.5)
		return
	end
	if os.clock() - lastFlare < 2 then
		return
	end
	lastFlare = os.clock()
	remotes.Flare:FireServer(camera.CFrame.LookVector)
end
local lastDash = -100
local function dash()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and root) or player:GetAttribute("Hidden") or not gui.Enabled or hum.Health <= 0 then
		return
	end
	if os.clock() - lastDash < (Config.DashCooldown or 8) or stamina < (Config.DashStamina or 25) then
		return
	end
	lastDash = os.clock()
	stamina -= Config.DashStamina or 25
	local dir = hum.MoveDirection.Magnitude > 0.1 and hum.MoveDirection or camera.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then
		return
	end
	dir = dir.Unit
	local att = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.MaxAxesForce = Vector3.new(1, 0, 1) * 1e5
	lv.VectorVelocity = dir * 58
	lv.Parent = root
	task.delay(0.2, function()
		lv:Destroy()
	end)
	camera.FieldOfView = 80
	TweenService:Create(camera, TweenInfo.new(0.4), { FieldOfView = 70 }):Play()
end
local function refreshAbilities()
	local parts = {}
	local n = player:GetAttribute("Flares")
	if n then
		table.insert(parts, "FLARES [G]: " .. n)
	end
	local syr = player:GetAttribute("Syringes")
	if syr then
		table.insert(parts, "SYRINGES: " .. syr)
	end
	local cd = math.ceil((Config.DashCooldown or 8) - (os.clock() - lastDash))
	table.insert(parts, cd > 0 and ("DASH [C]: " .. cd .. "s") or "DASH [C]: ready")
	abilityLabel.Text = table.concat(parts, "    ")
end
if touch then
	mbtn("DASH", UDim2.new(1, -300, 1, -150), Color3.fromRGB(90, 60, 30)).Activated:Connect(dash)
	mbtn("FLARE", UDim2.new(1, -300, 1, -210), Color3.fromRGB(120, 40, 30)).Activated:Connect(throwFlare)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		flashlightOn = not flashlightOn
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprintHeld = true
	elseif input.KeyCode == Enum.KeyCode.G then
		throwFlare()
	elseif input.KeyCode == Enum.KeyCode.C then
		dash()
	end
end)
-- Free mouse: press M (or the button) to unlock the cursor
local mouseFree = false
local freeHolder = Instance.new("TextButton")
freeHolder.Name = "FreeMouse"
freeHolder.Size = UDim2.fromOffset(150, 36)
freeHolder.Position = UDim2.new(1, -170, 0, 120)
freeHolder.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
freeHolder.BackgroundTransparency = 0.3
freeHolder.TextColor3 = Color3.new(1, 1, 1)
freeHolder.Font = Enum.Font.GothamBold
freeHolder.TextSize = 15
freeHolder.Text = "Free mouse [M]"
freeHolder.Parent = gui
Instance.new("UICorner", freeHolder)
local function setMouseFree(on)
	mouseFree = on
	freeHolder.Modal = on
	freeHolder.Text = on and "Lock mouse [M]" or "Free mouse [M]"
	freeHolder.BackgroundColor3 = on and Color3.fromRGB(40, 90, 140) or Color3.fromRGB(30, 30, 36)
	UserInputService.MouseIconEnabled = true
end
freeHolder.Activated:Connect(function()
	setMouseFree(not mouseFree)
end)
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.M and not UserInputService:GetFocusedTextBox() then
		setMouseFree(not mouseFree)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprintHeld = false
	end
end)
UserInputService.JumpRequest:Connect(function()
	if player:GetAttribute("Hidden") then
		remotes.LeaveHide:FireServer()
	end
end)

-- Checklist under the objective
local checklist = label(gui, { Size = UDim2.new(0.45, 0, 0, 90), Position = UDim2.fromOffset(20, 108), TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, TextSize = 18, Text = "", TextColor3 = Color3.fromRGB(200, 200, 190) })
local function refreshChecklist()
	local RS = ReplicatedStorage
	local fuses = RS:GetAttribute("ZooFuses") or 0
	local power = RS:GetAttribute("ZooPower") == true
	local phase = RS:GetAttribute("ZooPhase") or 0
	local handle = RS:GetAttribute("HandleFixed") == true
	local sed = RS:GetAttribute("SedativeFound") == true
	local laced = RS:GetAttribute("BaitLaced") == true
	local baited = RS:GetAttribute("BaitPlaced") == true or phase >= 3
	local clamps = RS:GetAttribute("ClampsLocked") or 0
	local called = RS:GetAttribute("PickupCalled") == true
	local need = Config.FusesNeeded or 3
	local mark = function(done) return done and "[x] " or "[ ] " end
	if phase >= 6 then
		checklist.Text = "[ ] KILL B-00\n"
			.. "  - STUN it [Q], then INJECT a syringe\n"
			.. "    (syringes + flares: red crates in the wreck)\n"
			.. "  - Throw a FLARE [G] into the fuel puddle\n"
			.. "    while it's standing in it\n"
			.. "  - Dodge its charge into the wreck/trees: DAZED"
		return
	elseif phase >= 5 then
		checklist.Text = "[x] B-00 caged and loaded in the van\n[ ] Survive the ride"
		return
	end
	checklist.Size = UDim2.new(0.42, 0, 0, 190)
	checklist.TextSize = 16
	checklist.Text = table.concat({
		mark(power) .. (power and "Power restored" or ("Fuses " .. fuses .. "/" .. need .. " -> generator")),
		mark(handle) .. "Winch handle -> cage lever",
		mark(sed) .. "Tranquilizer (medicine cabinet)",
		mark(laced or baited) .. "Lace meat at PREP COUNTER",
		mark(baited) .. "Laced bait on the cage plate",
		mark(phase >= 3) .. "Lure B-00 in + PULL LEVER",
		mark(phase >= 4) .. "Lock both clamps (" .. clamps .. "/2)",
		mark(called) .. "Radio Wildcrest (Security)",
		"[ ] Get back to the van",
	}, "\n")
end
for _, a in { "ZooFuses", "ZooPower", "ZooPhase", "BaitPlaced", "HandleFixed", "SedativeFound", "BaitLaced", "ClampsLocked", "PickupCalled" } do
	ReplicatedStorage:GetAttributeChangedSignal(a):Connect(refreshChecklist)
end
refreshChecklist()

-- Stun gun: Q (or the STUN button) zaps a monster in front of you
local stunLabel = label(gui, { Size = UDim2.fromOffset(220, 20), Position = UDim2.new(0, 20, 1, -108), TextXAlignment = Enum.TextXAlignment.Left,
	TextSize = 16, Text = "", TextColor3 = Color3.fromRGB(140, 210, 255) })
local function refreshStun()
	if player:GetAttribute("HasStunner") then
		stunLabel.Text = "STUN GUN [Q]: " .. (player:GetAttribute("StunCharges") or 0) .. " charges"
	else
		stunLabel.Text = ""
	end
end
player:GetAttributeChangedSignal("HasStunner"):Connect(refreshStun)
player:GetAttributeChangedSignal("StunCharges"):Connect(refreshStun)
refreshStun()
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(200, 230, 255)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 8
flash.Parent = gui
local lastShot = 0
local function fireStun()
	if not player:GetAttribute("HasStunner") or player:GetAttribute("Hidden") then
		return
	end
	if os.clock() - lastShot < (Config.StunCooldown or 2.5) or (player:GetAttribute("StunCharges") or 0) <= 0 then
		return
	end
	lastShot = os.clock()
	remotes.Stun:FireServer(camera.CFrame.LookVector)
	flash.BackgroundTransparency = 0.35
	TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	sound(Config.Sounds.Alarm, 0.6, 3)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Q then
		fireStun()
	end
end)
if touch then
	local b = mbtn("STUN", UDim2.new(1, -200, 1, -270), Color3.fromRGB(30, 60, 100))
	b.Activated:Connect(fireStun)
	local function vis()
		b.Visible = player:GetAttribute("HasStunner") == true
	end
	player:GetAttributeChangedSignal("HasStunner"):Connect(vis)
	vis()
end

local function refreshObjective()
	objective.Text = ReplicatedStorage:GetAttribute("ZooObjective") or ""
end
ReplicatedStorage:GetAttributeChangedSignal("ZooObjective"):Connect(refreshObjective)
refreshObjective()

-- Game pass buttons (hidden once you own them)
local buyLives = Instance.new("TextButton")
buyLives.Name = "BuyInfiniteLives"
buyLives.Size = UDim2.fromOffset(150, 36)
buyLives.Position = UDim2.new(1, -170, 0, 162)
buyLives.BackgroundColor3 = Color3.fromRGB(150, 30, 40)
buyLives.BackgroundTransparency = 0.15
buyLives.TextColor3 = Color3.new(1, 1, 1)
buyLives.Font = Enum.Font.GothamBold
buyLives.TextSize = 15
buyLives.Text = "\u{221E} Lives - R$39"
buyLives.Visible = false
buyLives.Parent = gui
Instance.new("UICorner", buyLives)
buyLives.Activated:Connect(function()
	if Config.InfiniteLivesPassId and Config.InfiniteLivesPassId ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, Config.InfiniteLivesPassId)
	end
end)
local buyNokia = buyLives:Clone()
buyNokia.Name = "BuyNokia"
buyNokia.Position = UDim2.new(1, -170, 0, 204)
buyNokia.BackgroundColor3 = Color3.fromRGB(40, 90, 150)
buyNokia.Text = "Nokia Flashlight - R$19"
buyNokia.TextSize = 13
buyNokia.Parent = gui
buyNokia.Activated:Connect(function()
	if Config.NokiaFlashlightPassId and Config.NokiaFlashlightPassId ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, Config.NokiaFlashlightPassId)
	end
end)
local batteryTitle
for _, d in batteryFill.Parent:GetChildren() do
	if d:IsA("TextLabel") then
		batteryTitle = d
	end
end
local function refreshNokia()
	local owns = player:GetAttribute("NokiaFlashlight") == true
	buyNokia.Visible = not owns and (Config.NokiaFlashlightPassId or 0) ~= 0 and player:GetAttribute("InGame") == true
	if batteryTitle then
		batteryTitle.Text = owns and "NOKIA FLASHLIGHT \u{221E} [F]" or "FLASHLIGHT [F]"
	end
end
player:GetAttributeChangedSignal("NokiaFlashlight"):Connect(refreshNokia)
player:GetAttributeChangedSignal("InGame"):Connect(refreshNokia)
refreshNokia()

local function refreshLives()
	local infinite = player:GetAttribute("InfiniteLives") == true
	livesLabel.Text = infinite and "\u{2665} \u{221E}" or string.rep("\u{2665} ", player:GetAttribute("Lives") or 0)
	buyLives.Visible = not infinite and (Config.InfiniteLivesPassId or 0) ~= 0 and player:GetAttribute("InGame") == true
end
player:GetAttributeChangedSignal("Lives"):Connect(refreshLives)
player:GetAttributeChangedSignal("InfiniteLives"):Connect(refreshLives)
player:GetAttributeChangedSignal("InGame"):Connect(refreshLives)
refreshLives()
local function refreshCarry()
	local who = ReplicatedStorage:GetAttribute("MoneyCarrier") or ""
	if player:GetAttribute("CarryingMoney") then
		carryLabel.Text = ReplicatedStorage:GetAttribute("BaitLaced") and "You're carrying LACED bait (slower)" or "You're carrying plain meat (slower)"
	elseif who ~= "" then
		carryLabel.Text = who .. " has the bait"
	else
		carryLabel.Text = ""
	end
end
ReplicatedStorage:GetAttributeChangedSignal("MoneyCarrier"):Connect(refreshCarry)
ReplicatedStorage:GetAttributeChangedSignal("BaitLaced"):Connect(refreshCarry)
local handleLabel = label(gui, { Size = UDim2.fromOffset(300, 24), Position = UDim2.new(1, -320, 0, 112), TextXAlignment = Enum.TextXAlignment.Right,
	TextSize = 18, TextColor3 = Color3.fromRGB(255, 160, 80), Text = "" })
player:GetAttributeChangedSignal("HasHandle"):Connect(function()
	handleLabel.Text = player:GetAttribute("HasHandle") and "Carrying: Winch Handle" or ""
end)
player:GetAttributeChangedSignal("CarryingMoney"):Connect(refreshCarry)
local function refreshHidden()
	hideHint.Text = player:GetAttribute("Hidden") and "Hiding... hold your breath.  [SPACE / Jump] to get out"
		or player:GetAttribute("Protected") and "You're safe for a few seconds - get moving!" or ""
end
player:GetAttributeChangedSignal("Protected"):Connect(refreshHidden)
player:GetAttributeChangedSignal("Hidden"):Connect(refreshHidden)

-- Per frame ------------------------------------------------------------------------------
local lastSent = {}
local sendAt = 0
local pulse = 0
RunService.RenderStepped:Connect(function(dt)
	beamPart.CFrame = camera.CFrame * CFrame.new(0.6, -0.5, -0.5)
	refreshAbilities()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local hidden = player:GetAttribute("Hidden") == true
	local inCutscene = not gui.Enabled
	local root = char:FindFirstChild("HumanoidRootPart")
	local monsters = level:FindFirstChild("Monsters")

	-- cage countdown + charge rumble
	local chargingNear = false
	local captiveBreaksIn
	if monsters then
		for _, m in monsters:GetChildren() do
			if m.Name == "Behemoth" then
				if m:GetAttribute("Trapped") then
					captiveBreaksIn = ReplicatedStorage:GetAttribute("ClampsLocked") or 0
				end
				if root and m.PrimaryPart and m:GetAttribute("Charging") and (m.PrimaryPart.Position - root.Position).Magnitude < 70 then
					chargingNear = true
				end
			end
		end
	end
	cageTimer.Text = captiveBreaksIn and ("TRAPPED! LOCK THE CLAMPS: " .. captiveBreaksIn .. "/2") or ""
	if not scared and not inCutscene then
		if chargingNear then
			camera.CFrame *= CFrame.Angles((math.random() - 0.5) * 0.03, (math.random() - 0.5) * 0.03, (math.random() - 0.5) * 0.02)
		end
		if os.clock() < shakeUntil then
			local k = shakeAmount * math.clamp((shakeUntil - os.clock()) / 0.8, 0, 1)
			camera.CFrame *= CFrame.Angles((math.random() - 0.5) * 0.07 * k, (math.random() - 0.5) * 0.07 * k, (math.random() - 0.5) * 0.04 * k)
		else
			shakeAmount = 0
		end
	end

	local nokia = player:GetAttribute("NokiaFlashlight") == true
	if nokia then
		battery = Config.BatteryMax
	end
	if flashlightOn and battery > 0 and not nokia then
		local dd = Config.Difficulties and Config.Difficulties[ReplicatedStorage:GetAttribute("Difficulty") or ""]
		local ft = Config.ShopTier and Config.ShopTier("Flashlight", player:GetAttribute("FlashTier") or 1)
		battery = math.max(0, battery - Config.BatteryDrain * dt * (dd and dd.Battery or 1) * (ft and ft.Drain or 1))
	end
	if battery <= 0 then
		flashlightOn = false
	end
	local lightOn = flashlightOn and battery > 0 and not hidden and not inCutscene
	if lightOn and battery < 15 and math.random() < 0.08 then
		lightOn = false
	end
	spot.Enabled = lightOn
	glow.Enabled = lightOn
	local ftier = Config.ShopTier and Config.ShopTier("Flashlight", player:GetAttribute("FlashTier") or 1)
	spot.Brightness = (ftier and ftier.Brightness or 3.5) * math.clamp(battery / 30, 0.35, 1)
	spot.Range = ftier and ftier.Range or 60
	local beam = ({ ice = Color3.fromRGB(170, 220, 255), uv = Color3.fromRGB(190, 120, 255), red = Color3.fromRGB(255, 110, 100) })[player:GetAttribute("Up_FlashSkin") or ""]
	spot.Color = beam or Color3.fromRGB(255, 245, 225)
	spot.Angle = ftier and ftier.Angle or 50
	batteryFill.Size = UDim2.fromScale(battery / Config.BatteryMax, 1)

	local moving = hum.MoveDirection.Magnitude > 0.1 and not hidden
	local sprinting = sprintHeld and moving and stamina > 1
	if sprinting then
		local sh = Config.ShopTier and Config.ShopTier("Shoes", player:GetAttribute("ShoeTier") or 1)
		stamina = math.max(0, stamina - Config.StaminaDrain * dt / (sh and sh.Stamina or 1))
	else
		stamina = math.min(Config.StaminaMax, stamina + Config.StaminaRegen * dt * (moving and 0.6 or 1))
	end
	local speed
	if player:GetAttribute("CarryingMoney") then
		speed = sprinting and Config.CarrySprintSpeed or Config.CarryWalkSpeed
	else
		speed = sprinting and Config.SprintSpeed or Config.WalkSpeed
	end
	if workspace:GetServerTimeNow() < (player:GetAttribute("SlowedUntil") or 0) then
		speed *= 0.5 -- ground slam
	end
	hum.WalkSpeed = speed * (player:GetAttribute("AdminSpeed") or 1)
	staminaFill.Size = UDim2.fromScale(stamina / Config.StaminaMax, 1)
	staminaFill.BackgroundColor3 = stamina < 25 and Color3.fromRGB(255, 120, 80) or Color3.fromRGB(120, 200, 255)

	local state = { Sprinting = sprinting, Moving = moving, Flashlight = flashlightOn and battery > 0 }
	if os.clock() > sendAt and (state.Sprinting ~= lastSent.Sprinting or state.Moving ~= lastSent.Moving or state.Flashlight ~= lastSent.Flashlight) then
		sendAt = os.clock() + 0.15
		lastSent = state
		remotes.State:FireServer(state)
	end

	local nearest, chased = math.huge, false
	if root and monsters then
		for _, m in monsters:GetChildren() do
			if m.PrimaryPart and not m:GetAttribute("Captured") and not m:GetAttribute("Trapped") then
				nearest = math.min(nearest, (m.PrimaryPart.Position - root.Position).Magnitude)
			end
			if m:GetAttribute("Chasing") == player.Name then
				chased = true
			end
		end
	end
	local danger = math.clamp((45 - nearest) / 45, 0, 1)
	if chased then
		danger = math.max(danger, 0.6)
	end
	pulse += dt * (2 + danger * 6)
	local beat = (math.sin(pulse) + 1) / 2
	for _, e in edges do
		e.BackgroundTransparency = 1 - danger * (0.35 + beat * 0.4)
	end
	if chased and not scared and not inCutscene then
		camera.CFrame *= CFrame.Angles(math.rad(math.random() - 0.5) * 0.4, math.rad(math.random() - 0.5) * 0.4, 0)
	end
	if chokeUI.Visible then
		danger = 1 -- being choked: the heart pounds
	end
	heartbeat.Volume = danger * 1.2
	heartbeat.PlaybackSpeed = 1 + danger * 0.4

	local alarm = ReplicatedStorage:GetAttribute("Alarm") == true and not inCutscene
	alarmTint.Enabled = alarm
	alarmSound.Volume = alarm and 0.35 or 0
	if alarm then
		local a = (math.sin(os.clock() * 5) + 1) / 2
		alarmTint.TintColor = Color3.fromRGB(255, 255, 255):Lerp(Color3.fromRGB(255, 120, 110), a)
	end
end)

player.CharacterAdded:Connect(function()
	stamina = Config.StaminaMax
	battery = Config.BatteryMax
	flashlightOn = true
	refreshHidden()
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
				local b = light.Brightness
				light.Brightness = b * math.random() * 0.3
				if baseColor then bulb.Color = baseColor:Lerp(Color3.new(0, 0, 0), 0.7) end
				task.wait(math.random() * 0.12 + 0.03)
				light.Brightness = b
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

-- Security radar: outline monsters + key items through walls for a few seconds.
local radarItems = {
	Fuse = { "FUSE", Color3.fromRGB(255, 170, 50) },
	Bait = { "BAIT", Color3.fromRGB(255, 90, 100) },
	Sedative = { "TRANQUILIZER", Color3.fromRGB(190, 140, 255) },
	Syringe = { "SYRINGE", Color3.fromRGB(190, 140, 255) },
	FlarePickup = { "FLARE", Color3.fromRGB(255, 90, 60) },
	WinchHandle = { "WINCH HANDLE", Color3.fromRGB(255, 140, 60) },
	StunGun = { "STUN GUN", Color3.fromRGB(120, 200, 255) },
	StunCartridge = { "CARTRIDGE", Color3.fromRGB(120, 200, 255) },
	Battery = { "BATTERY", Color3.fromRGB(240, 210, 80) },
	Cash = { "$", Color3.fromRGB(150, 230, 110) },
}
remotes:WaitForChild("RadarPing").OnClientEvent:Connect(function(duration)
	local made = {}
	local function mark(target, color, text, isMonster)
		local h = Instance.new("Highlight")
		h.Adornee = target
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.FillColor = color
		h.FillTransparency = isMonster and 0.55 or 0.4
		h.OutlineColor = color
		h.OutlineTransparency = 0
		h.Parent = workspace.CurrentCamera
		table.insert(made, h)
		local part = target:IsA("Model") and target.PrimaryPart or target
		if part then
			local bb = Instance.new("BillboardGui")
			bb.Adornee = part
			bb.AlwaysOnTop = true
			bb.Size = UDim2.fromOffset(110, 24)
			bb.StudsOffset = Vector3.new(0, isMonster and 6 or 2, 0)
			bb.Parent = player.PlayerGui
			local l = Instance.new("TextLabel")
			l.Size = UDim2.fromScale(1, 1)
			l.BackgroundTransparency = 1
			l.Font = Enum.Font.GothamBold
			l.TextScaled = true
			l.TextColor3 = color
			l.TextStrokeTransparency = 0.3
			l.Text = text
			l.Parent = bb
			table.insert(made, bb)
		end
	end
	local mons = level:FindFirstChild("Monsters")
	if mons then
		for _, m in mons:GetChildren() do
			mark(m, Color3.fromRGB(255, 40, 40), m.Name == "Behemoth" and "B-00" or string.upper(m.Name), true)
		end
	end
	local items = level:FindFirstChild("Items")
	if items then
		local count = 0
		for _, it in items:GetChildren() do
			local info = radarItems[it.Name]
			if info and count < 24 then -- Roblox shows at most 31 highlights at once
				count += 1
				mark(it, info[2], info[1], false)
			end
		end
	end
	sound(Config.Sounds.Alarm, 0.5, 2.2)
	local sweep = Instance.new("Frame")
	sweep.Size = UDim2.fromScale(1, 1)
	sweep.BackgroundColor3 = Color3.fromRGB(60, 255, 120)
	sweep.BackgroundTransparency = 0.75
	sweep.BorderSizePixel = 0
	sweep.Parent = gui
	TweenService:Create(sweep, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	task.delay(duration or 8, function()
		for _, x in made do
			x:Destroy()
		end
		sweep:Destroy()
	end)
end)

-- Radar station screen + spinning dish
task.spawn(function()
	local radar = level:WaitForChild("RadarStation", 10)
	if not radar then
		return
	end
	local status = radar:FindFirstChild("Status", true)
	local dish = radar:FindFirstChild("Dish")
	local home = dish and dish:GetPivot()
	local angle = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		local readyAt = ReplicatedStorage:GetAttribute("RadarReadyAt") or 0
		local activeUntil = ReplicatedStorage:GetAttribute("RadarActiveUntil") or 0
		local active = now < activeUntil
		angle += dt * (active and 6 or 0.8)
		if dish then
			dish:PivotTo(home * CFrame.Angles(0, angle, 0))
		end
		local dd = Config.Difficulties and Config.Difficulties[ReplicatedStorage:GetAttribute("Difficulty") or ""]
		if status and dd and not dd.RadarCooldown then
			status.Text = "MALL RADAR\nOFFLINE"
			status.TextColor3 = Color3.fromRGB(120, 120, 120)
		elseif status then
			if active then
				status.Text = "MALL RADAR\nSCANNING..."
				status.TextColor3 = Color3.fromRGB(255, 230, 90)
			elseif now < readyAt then
				status.Text = ("MALL RADAR\nRECHARGING %ds"):format(math.ceil(readyAt - now))
				status.TextColor3 = Color3.fromRGB(255, 90, 80)
			else
				status.Text = "MALL RADAR\nREADY"
				status.TextColor3 = Color3.fromRGB(90, 255, 120)
			end
		end
	end)
end)

-- Difficulty picker (shown at the start of each round) + HUD tag
do
	local picker = Instance.new("Frame")
	picker.Name = "DifficultyPicker"
	picker.AnchorPoint = Vector2.new(0.5, 0.5)
	picker.Position = UDim2.fromScale(0.5, 0.5)
	picker.Size = UDim2.fromOffset(620, 340)
	picker.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
	picker.BackgroundTransparency = 0.1
	picker.Visible = false
	picker.Parent = overlay
	Instance.new("UICorner", picker).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(160, 80, 20)
	stroke.Thickness = 2
	stroke.Parent = picker
	label(picker, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 10), Font = Enum.Font.Creepster, TextScaled = true,
		TextColor3 = Color3.fromRGB(240, 170, 90), Text = "LAST CALL - CHOOSE YOUR NIGHT" })
	local timer = label(picker, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -30), TextSize = 16,
		TextColor3 = Color3.fromRGB(170, 170, 170), Text = "" })
	local order = Config.DifficultyOrder or { "Easy", "Normal", "Hard", "Nightmare" }
	for i, name in order do
		local d = Config.Difficulties[name]
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(136, 220)
		b.Position = UDim2.fromOffset(16 + (i - 1) * 150, 70)
		b.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
		b.AutoButtonColor = true
		b.Text = ""
		b.Modal = true
		b.Parent = picker
		Instance.new("UICorner", b)
		local s2 = Instance.new("UIStroke")
		s2.Color = d.Color
		s2.Thickness = 2
		s2.Parent = b
		label(b, { Size = UDim2.new(1, -10, 0, 36), Position = UDim2.fromOffset(5, 8), Font = Enum.Font.GothamBlack, TextScaled = true,
			TextColor3 = d.Color, Text = string.upper(name) })
		label(b, { Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 48), TextSize = 22, TextColor3 = Color3.fromRGB(255, 110, 110),
			Text = string.rep("\u{2665}", d.Lives) })
		label(b, { Size = UDim2.new(1, -16, 1, -90), Position = UDim2.fromOffset(8, 80), TextWrapped = true, TextScaled = true,
			TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(210, 210, 200), Text = d.Blurb or "" })
		b.Activated:Connect(function()
			remotes.ChooseDifficulty:FireServer(name)
		end)
	end
	local tag = label(gui, { Size = UDim2.fromOffset(200, 24), Position = UDim2.new(1, -220, 0, 24), TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 18, Font = Enum.Font.GothamBlack, Text = "" })
	local function refresh()
		local choosing = ReplicatedStorage:GetAttribute("DifficultyChoosing") == true and player:GetAttribute("InGame") == true
		picker.Visible = choosing and not introPlaying
		local name = ReplicatedStorage:GetAttribute("Difficulty") or ""
		local d = Config.Difficulties[name]
		tag.Text = d and string.upper(name) or ""
		tag.TextColor3 = d and d.Color or Color3.new(1, 1, 1)
	end
	ReplicatedStorage:GetAttributeChangedSignal("DifficultyChoosing"):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal("Difficulty"):Connect(refresh)
	player:GetAttributeChangedSignal("InGame"):Connect(refresh)
	refresh()
	RunService.Heartbeat:Connect(function()
		if picker.Visible ~= (ReplicatedStorage:GetAttribute("DifficultyChoosing") == true and player:GetAttribute("InGame") == true and not introPlaying) then
			refresh()
		end
		if picker.Visible then
			local left = math.max(0, math.ceil((ReplicatedStorage:GetAttribute("DifficultyDeadline") or 0) - workspace:GetServerTimeNow()))
			timer.Text = "Anyone can choose. Defaults to NORMAL in " .. left .. "s"
		end
	end)
end

-- Cash counter + Supply Machine shop
do
	local cashLabel = label(gui, { Size = UDim2.fromOffset(200, 26), Position = UDim2.new(1, -220, 0, 246), TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 22, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(130, 240, 120), Text = "" })
	local function fmt(n)
		local s = tostring(math.floor(n or 0))
		return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
	end
	local function refreshCash()
		cashLabel.Text = "$" .. fmt(player:GetAttribute("Cash"))
	end
	player:GetAttributeChangedSignal("Cash"):Connect(refreshCash)
	refreshCash()

	local shop = Instance.new("Frame")
	shop.Name = "Shop"
	shop.AnchorPoint = Vector2.new(0.5, 0.5)
	shop.Position = UDim2.fromScale(0.5, 0.5)
	shop.Size = UDim2.fromOffset(560, 380)
	shop.BackgroundColor3 = Color3.fromRGB(16, 22, 18)
	shop.BackgroundTransparency = 0.05
	shop.Visible = false
	shop.Parent = overlay
	Instance.new("UICorner", shop).CornerRadius = UDim.new(0, 10)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(60, 140, 80)
	st.Thickness = 2
	st.Parent = shop
	label(shop, { Size = UDim2.new(1, -120, 0, 44), Position = UDim2.fromOffset(18, 10), Font = Enum.Font.GothamBlack, TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(230, 200, 60), Text = "WILDCREST SUPPLY" })
	local shopCash = label(shop, { Size = UDim2.fromOffset(160, 30), Position = UDim2.new(1, -220, 0, 16), TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 22, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(130, 240, 120), Text = "" })
	local result = label(shop, { Size = UDim2.new(1, -36, 0, 24), Position = UDim2.new(0, 18, 1, -34), TextSize = 18, Text = "" })
	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(40, 40)
	close.Position = UDim2.new(1, -52, 0, 12)
	close.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.GothamBlack
	close.TextSize = 20
	close.Text = "X"
	close.Modal = true
	close.Parent = shop
	Instance.new("UICorner", close)
	close.Activated:Connect(function()
		shop.Visible = false
	end)
	local rows = {}
	local attrFor = { Flashlight = "FlashTier", Shoes = "ShoeTier", Stun = "StunTier" }
	local function refreshShop()
		shopCash.Text = "$" .. fmt(player:GetAttribute("Cash"))
		for id, r in rows do
			local cur = player:GetAttribute(attrFor[id]) or 1
			local tier, item = Config.ShopTier(id, cur)
			local nxt = item.Tiers[cur + 1]
			r.cur.Text = item.Name .. ": " .. tier.Name .. "  (" .. cur .. "/" .. #item.Tiers .. ")"
			if nxt then
				r.desc.Text = "Next: " .. nxt.Name .. " - " .. (nxt.Text or "")
				r.buy.Text = "$" .. fmt(nxt.Price)
				r.buy.BackgroundColor3 = (player:GetAttribute("Cash") or 0) >= nxt.Price and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(70, 70, 75)
			else
				r.desc.Text = "Fully upgraded."
				r.buy.Text = "MAX"
				r.buy.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
			end
		end
	end
	for i, item in Config.Shop do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -36, 0, 84)
		row.Position = UDim2.fromOffset(18, 62 + (i - 1) * 94)
		row.BackgroundColor3 = Color3.fromRGB(28, 36, 30)
		row.Parent = shop
		Instance.new("UICorner", row)
		local cur = label(row, { Size = UDim2.new(1, -150, 0, 30), Position = UDim2.fromOffset(12, 8), TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 20, Font = Enum.Font.GothamBold, Text = "" })
		local desc = label(row, { Size = UDim2.new(1, -150, 0, 40), Position = UDim2.fromOffset(12, 38), TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, TextSize = 16, TextColor3 = Color3.fromRGB(190, 200, 190), Text = "" })
		local buy = Instance.new("TextButton")
		buy.Size = UDim2.fromOffset(120, 50)
		buy.Position = UDim2.new(1, -132, 0.5, -25)
		buy.TextColor3 = Color3.new(1, 1, 1)
		buy.Font = Enum.Font.GothamBlack
		buy.TextSize = 20
		buy.Parent = row
		Instance.new("UICorner", buy)
		buy.Activated:Connect(function()
			local ok, msg = remotes.Shop:InvokeServer("buy", item.Id)
			result.Text = msg or ""
			result.TextColor3 = ok and Color3.fromRGB(130, 240, 120) or Color3.fromRGB(255, 120, 110)
			refreshShop()
		end)
		rows[item.Id] = { cur = cur, desc = desc, buy = buy }
	end
	for _, a in { "Cash", "FlashTier", "ShoeTier", "StunTier" } do
		player:GetAttributeChangedSignal(a):Connect(function()
			if shop.Visible then
				refreshShop()
			end
		end)
	end
	remotes:WaitForChild("OpenShop").OnClientEvent:Connect(function()
		result.Text = ""
		refreshShop()
		shop.Visible = true
	end)
end

-- Hiding spots with an OccupiedSign turn red while someone is inside.
for _, hs in CollectionService:GetTagged("HideSpot") do
	local sign = hs:FindFirstChild("OccupiedSign")
	if sign then
		local function refresh()
			sign.Color = hs:GetAttribute("Occupant") and Color3.fromRGB(200, 30, 30) or Color3.fromRGB(30, 160, 60)
		end
		hs:GetAttributeChangedSignal("Occupant"):Connect(refresh)
		refresh()
	end
end

-- INTRO: Wildcrest HQ. The Director blames you for B-00 getting loose... then the van ride to the mall.
local function playIntro()
	introPlaying = true
	local skipped = false
	local char = player.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if myRoot then
		myRoot.Anchored = true
	end
	gui.Enabled = false
	camera.CameraType = Enum.CameraType.Scriptable
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	local savedDensity = atmo and atmo.Density
	if atmo then
		atmo.Density = 0
	end
	local office = ReplicatedStorage:WaitForChild("IntroOffice"):Clone()
	local O = CFrame.new(2600, 300, 0)
	office:PivotTo(O)
	office.Parent = workspace
	local man = office:FindFirstChild("Director")
	local manRoot = man and man:FindFirstChild("HumanoidRootPart")
	local manHome = man and man:GetPivot()
	local function motor(name)
		local m = man and man:FindFirstChild(name, true)
		return m and m:IsA("Motor6D") and m or nil
	end
	local neck, waist, rs, lsh = motor("Neck"), motor("Waist"), motor("RightShoulder"), motor("LeftShoulder")
	local flash = office:FindFirstChild("Lightning") and office.Lightning:FindFirstChild("Flash")
	local function P(x, y, z) -- office-local point
		return (O * CFrame.new(x, y, z)).Position
	end

	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BorderSizePixel = 0
	black.ZIndex = 50
	black.Parent = overlay
	local bars = {}
	for i, pos in { UDim2.fromScale(0, 0), UDim2.new(0, 0, 0.9, 0) } do
		local b = Instance.new("Frame")
		b.Size = UDim2.fromScale(1, i == 2 and 0.16 or 0.1)
		b.Position = i == 2 and UDim2.fromScale(0, 0.84) or pos
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.BorderSizePixel = 0
		b.ZIndex = 48
		b.Parent = overlay
		bars[i] = b
	end
	local card = label(overlay, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromScale(0, 0.42), Font = Enum.Font.Creepster, TextScaled = true,
		TextColor3 = Color3.fromRGB(230, 200, 150), Text = "", ZIndex = 52 })
	local cardSub = label(overlay, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromScale(0, 0.52), TextSize = 22,
		TextColor3 = Color3.fromRGB(170, 170, 170), Text = "", ZIndex = 52 })
	local speaker = label(overlay, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromScale(0, 0.85), TextSize = 16, Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(220, 170, 80), Text = "", ZIndex = 49 })
	local line = label(overlay, { Size = UDim2.new(0.76, 0, 0.12, 0), Position = UDim2.fromScale(0.07, 0.875), TextSize = 21, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, Text = "", ZIndex = 49 })
	local skip = Instance.new("TextButton")
	skip.Size = UDim2.fromOffset(120, 40)
	skip.Position = UDim2.new(1, -140, 1, -60)
	skip.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	skip.BackgroundTransparency = 0.2
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.Font = Enum.Font.GothamBold
	skip.TextSize = 18
	skip.Text = "SKIP \u{25B6}"
	skip.ZIndex = 55
	skip.Modal = true
	skip.Parent = overlay
	Instance.new("UICorner", skip)
	skip.Activated:Connect(function()
		skipped = true
	end)

	local dialogue = {
		{ 4.6, "...You. Sit down." },
		{ 7, "We sent you into that zoo for one job: get our money out of the safe. And you did. Good work." },
		{ 12.5, "But you left the gates wide open. B-00 followed YOUR van out. It is loose because of YOU." },
		{ 18, "Last sighting: our old mall on Route 9. Condemned. Empty. The perfect place for it to hide." },
		{ 23.5, "So you're going back out there, and you're bringing it home. ALIVE." },
		{ 28.5, "Get the power on. There's a containment cage on the loading dock. Use it." },
		{ 33, "Do this, and you keep your job. Fail..." },
		{ 37, "...and B-00 will be the least of your problems." },
	}
	local curLine, curStart = nil, 0
	local slammed = false
	local van = level:FindFirstChild("Van")
	local vanHome = van and van:GetPivot()
	local roadY = vanHome and vanHome.Position.Y or 3.9
	local beams = {}
	if van then
		for _, hl in van:GetChildren() do
			if hl.Name == "Headlight" and hl:IsA("BasePart") then
				local sl = Instance.new("SpotLight")
				sl.Face = Enum.NormalId.Back -- the van's front is +Z
				sl.Range = 45
				sl.Angle = 50
				sl.Brightness = 3
				sl.Color = Color3.fromRGB(255, 245, 220)
				sl.Shadows = true
				sl.Parent = hl
				table.insert(beams, sl)
			end
		end
	end
	local t0 = os.clock()
	local fadeOutAt, arrivalAt, endAt = 39.6, 40.6, 50
	sound(Config.Sounds.Ambience, 0.4, 0.8)
	while not skipped do
		local t = os.clock() - t0
		if t > endAt then
			break
		end
		-- title cards
		if t < 3 then
			card.Text = "WILDCREST CORP. HEADQUARTERS"
			cardSub.Text = "The night after Closing Time"
		elseif t < arrivalAt then
			card.Text, cardSub.Text = "", ""
		elseif t < 44.2 then
			card.Text = "CHAPTER 2: LAST CALL"
			cardSub.Text = ""
		else
			card.Text = ""
		end
		-- fades
		if t < 3 then
			black.BackgroundTransparency = 0
		elseif t < 4 then
			black.BackgroundTransparency = t - 3
		elseif t > fadeOutAt and t < arrivalAt then
			black.BackgroundTransparency = 1 - (t - fadeOutAt)
		elseif t >= arrivalAt and t < arrivalAt + 1.6 then
			black.BackgroundTransparency = t < 44.2 and 0.35 or math.min(1, (t - arrivalAt))
		elseif t > endAt - 1 then
			black.BackgroundTransparency = math.max(0, endAt - t)
		else
			black.BackgroundTransparency = 1
		end
		-- dialogue (typewriter)
		for i, d in dialogue do
			if t >= d[1] and (not dialogue[i + 1] or t < dialogue[i + 1][1]) and t < fadeOutAt then
				if curLine ~= i then
					curLine, curStart = i, t
				end
				speaker.Text = "DIRECTOR MARSH"
				line.Text = string.sub(d[2], 1, math.floor((t - curStart) * 38))
			end
		end
		if t >= fadeOutAt then
			speaker.Text, line.Text = "", ""
		end
		if t < arrivalAt then
			-- the office ----------------------------------------------------------
			if flash then
				flash.Brightness = (t > 3.6 and t < 3.75) and 6 or ((t > 3.85 and t < 3.95) and 4 or ((t > 25 and t < 25.12) and 5 or 0))
			end
			if man and manRoot then
				local turn = math.clamp((t - 4.6) / 1.2, 0, 1)
				turn = turn * turn * (3 - 2 * turn)
				man:PivotTo(manHome * CFrame.Angles(0, math.pi * turn, 0) + (manHome.LookVector * -0.0))
				local talking = curLine and t - curStart < #dialogue[curLine][2] / 38 + 0.3
				local nod = talking and math.sin(t * 7) * 0.05 or 0
				local look = (t > 18 and t < 21.5) and 0.7 or 0 -- glances at the monitor
				if neck then
					neck.Transform = CFrame.Angles(nod, look, 0)
				end
				local point = (t > 13.2 and t < 17.5) and math.clamp((t - 13.2) * 3, 0, 1) or 0
				local lean = t > 33 and math.clamp((t - 33) * 2, 0, 1) or 0
				if waist then
					waist.Transform = CFrame.Angles(-0.35 * lean, 0, 0)
				end
				local slamArm = 0
				if t > 36.6 then
					if not slammed then
						slammed = true
						sound(Config.Sounds.Jumpscare, 0.6, 0.35)
						shakeAmount, shakeUntil = 1.3, os.clock() + 0.7
					end
					slamArm = math.clamp(1 - (t - 36.6) * 4, 0, 1)
				end
				if rs then
					rs.Transform = CFrame.Angles(math.rad(85) * point + math.rad(55) * lean + math.rad(50) * slamArm, 0, 0)
				end
				if lsh then
					lsh.Transform = CFrame.Angles(math.rad(55) * lean + math.rad(50) * slamArm, 0, 0)
				end
			end
			local face = manRoot and (manRoot.Position + Vector3.new(0, 2.2, 0)) or P(0, 6, -10)
			local camCF
			if t < 6.5 then
				camCF = CFrame.lookAt(P(9, 7.5, 10) + Vector3.new(-t * 0.3, 0, 0), face - Vector3.new(0, 1, 0))
			elseif t < 12.5 then
				local k = (t - 6.5) / 6
				camCF = CFrame.lookAt(P(0, 5.6, 4 - k * 1.5), face)
			elseif t < 18 then
				camCF = CFrame.lookAt(P(6.5, 3.4, -5.5), face + Vector3.new(0, 0.3, 0)) -- low angle from beside the desk, he points at you
			elseif t < 21.5 then
				camCF = CFrame.lookAt(P(1.2, 5.6, -2.2), P(3, 5.5, -5)) -- the monitor
			elseif t < 28.5 then
				local k = (t - 21.5) / 7
				camCF = CFrame.lookAt(P(-3 + k, 5.4, 2), face)
			elseif t < 33 then
				camCF = CFrame.lookAt(P(-9, 8, -1), face) -- wide, the map board behind you
			else
				local k = math.clamp((t - 33) / 4, 0, 1)
				camCF = CFrame.lookAt(P(0, 5.2, 1.5 - k * 2.5), face) -- pushes in as he leans over the desk
			end
			camera.CFrame = camCF
			camera.FieldOfView = 60
			if os.clock() < shakeUntil then
				camera.CFrame *= CFrame.Angles((math.random() - 0.5) * 0.06, (math.random() - 0.5) * 0.06, 0)
			end
		else
			-- the drive to the mall -------------------------------------------------
			if atmo and savedDensity then
				atmo.Density = savedDensity
			end
			local u = t - arrivalAt
			local z = 640 - math.min(u, 6.8) * 62 + math.max(0, u - 6.8) * 0 -- fast down the road
			local brake = math.clamp((u - 6.2) / 1.6, 0, 1)
			z = math.max(z, 158)
			if van then
				van:PivotTo(CFrame.new(0, roadY + math.sin(u * 18) * 0.04, z) * CFrame.Angles(0, math.pi, 0))
			end
			local vanPos = Vector3.new(0, roadY, z)
			if u < 3.6 then
				camera.CFrame = CFrame.lookAt(Vector3.new(15, 3, 380), vanPos + Vector3.new(0, 2, 0))
				camera.FieldOfView = 55
			elseif u < 6.8 then
				camera.CFrame = CFrame.lookAt(Vector3.new(-22, 7, 150), vanPos:Lerp(Vector3.new(0, 18, 90), 0.35))
				camera.FieldOfView = 65
			else
				-- the mall sign, condemned, dark
				camera.CFrame = CFrame.lookAt(Vector3.new(6, 5 + u * 0.15, 150), Vector3.new(0, 22, 90))
				if u > 7.2 then
					speaker.Text = ""
					line.Text = "Wildcrest Mall. Something big is breathing inside."
				end
			end
		end
		RunService.Heartbeat:Wait() -- (keeps going even if the window isn't drawing)
	end
	-- restore
	if atmo and savedDensity then
		atmo.Density = savedDensity
	end
	for _, sl in beams do
		sl:Destroy()
	end
	if van and vanHome then
		van:PivotTo(vanHome)
	end
	office:Destroy()
	for _, b in bars do
		b:Destroy()
	end
	card:Destroy()
	cardSub:Destroy()
	speaker:Destroy()
	line:Destroy()
	skip:Destroy()
	camera.FieldOfView = 70
	camera.CameraType = Enum.CameraType.Custom
	if myRoot and myRoot.Parent then
		myRoot.Anchored = false
	end
	gui.Enabled = true
	introPlaying = false
	TweenService:Create(black, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
	task.delay(1.2, function()
		black:Destroy()
	end)
	notice("The van drops you at the mall. Something big is breathing inside.", nil, 4)
end

task.spawn(function()
	-- once per visit, at the start of a round
	while player:GetAttribute("InGame") ~= true do
		player:GetAttributeChangedSignal("InGame"):Wait()
	end
	task.wait(0.5)
	local left = (ReplicatedStorage:GetAttribute("IntroUntil") or 0) - workspace:GetServerTimeNow()
	if ReplicatedStorage:GetAttribute("DifficultyChoosing") == true and left > 5 then
		local ok, err = pcall(playIntro)
		if not ok then
			warn("Intro error: " .. tostring(err))
			introPlaying = false
			gui.Enabled = true
			camera.CameraType = Enum.CameraType.Custom
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if r then
				r.Anchored = false
			end
		end
	end
end)

-- Objective marker: a small diamond + distance on the next FIXED place to go (not on items you
-- have to search for - that's what the radar is for). [H] hides it.
do
	local markerOn = true
	local bb = Instance.new("BillboardGui")
	bb.Name = "ObjectiveMarker"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(140, 46)
	bb.LightInfluence = 0
	bb.Enabled = false
	bb.Parent = player.PlayerGui
	local diamond = Instance.new("Frame")
	diamond.Size = UDim2.fromOffset(12, 12)
	diamond.AnchorPoint = Vector2.new(0.5, 0)
	diamond.Position = UDim2.fromScale(0.5, 0)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = Color3.fromRGB(255, 210, 110)
	diamond.BackgroundTransparency = 0.15
	diamond.BorderSizePixel = 0
	diamond.Parent = bb
	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.new(1, 0, 0, 26)
	txt.Position = UDim2.fromOffset(0, 18)
	txt.BackgroundTransparency = 1
	txt.Font = Enum.Font.GothamBold
	txt.TextSize = 13
	txt.TextColor3 = Color3.fromRGB(255, 225, 160)
	txt.TextStrokeTransparency = 0.4
	txt.Parent = bb
	local hint = label(gui, { Size = UDim2.fromOffset(150, 18), Position = UDim2.new(1, -170, 0, 276), TextSize = 13,
		TextColor3 = Color3.fromRGB(170, 170, 170), Text = "Objective marker [H]", TextXAlignment = Enum.TextXAlignment.Right })
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.H then
			markerOn = not markerOn
			hint.Text = markerOn and "Objective marker [H]" or "Marker hidden [H]"
		end
	end)
	local function find(path)
		local cur = level
		for _, n in path do
			cur = cur and cur:FindFirstChild(n)
		end
		return cur
	end
	local function target()
		local RS = ReplicatedStorage
		local phase = RS:GetAttribute("ZooPhase") or 0
		if phase < 1 or phase >= 5 or not player:GetAttribute("InGame") then
			return nil
		end
		if not RS:GetAttribute("ZooPower") then
			if (RS:GetAttribute("ZooFuses") or 0) >= (Config.FusesNeeded or 3) then
				return find({ "Stores", "MAINTENANCE", "Generator" }), "GENERATOR"
			end
			return nil
		end
		if not RS:GetAttribute("HandleFixed") and player:GetAttribute("HasHandle") then
			return find({ "CaptureCage", "Lever", "Box" }), "CAGE LEVER"
		end
		if phase == 3 then
			local clamps = find({ "CaptureCage", "Clamps" })
			local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local best, bestD
			for _, cl in clamps and clamps:GetChildren() or {} do
				local light = cl:FindFirstChild("Light")
				local locked = light and light.Color.G > light.Color.R
				if not locked and cl:FindFirstChild("Box") and myRoot then
					local d = (cl.Box.Position - myRoot.Position).Magnitude
					if not bestD or d < bestD then
						best, bestD = cl.Box, d
					end
				end
			end
			return best, "CLAMP"
		end
		if phase >= 4 then
			if RS:GetAttribute("PickupCalled") then
				return find({ "ExitZone" }), "VAN"
			end
			return find({ "CaptureProps", "Radio" }), "RADIO (SECURITY)"
		end
		-- baiting
		if RS:GetAttribute("BaitPlaced") then
			return RS:GetAttribute("HandleFixed") and find({ "CaptureCage", "Lever", "Box" }) or nil, "CAGE LEVER"
		end
		if player:GetAttribute("CarryingMoney") then
			if RS:GetAttribute("BaitLaced") then
				return find({ "CaptureCage", "BaitPlate" }), "CAGE PLATE"
			end
			if RS:GetAttribute("SedativeFound") then
				return find({ "CaptureProps", "PrepBoard" }), "PREP COUNTER"
			end
			return nil
		end
		if RS:GetAttribute("SedativeFound") and (RS:GetAttribute("MoneyCarrier") or "") == "" then
			return find({ "FoodCourt", "Freezer" }), "FREEZER (MEAT)"
		end
		return nil
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local part, name = target()
		if part and part:IsA("Model") then
			part = part.PrimaryPart or part:FindFirstChildWhichIsA("BasePart")
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local show = markerOn and part ~= nil and root ~= nil and gui.Enabled and not introPlaying
		bb.Enabled = show
		if show then
			bb.Adornee = part
			bb.StudsOffset = Vector3.new(0, 3, 0)
			local d = (part.Position - root.Position).Magnitude
			txt.Text = ("%s  %dm"):format(name or "", math.floor(d / 3.5))
			bb.Enabled = d > 10
		end
	end)
end
