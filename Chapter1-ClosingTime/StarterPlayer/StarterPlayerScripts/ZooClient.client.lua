-- Closing Time client (zoo place): first person, flashlight, sprint, HUD,
-- hiding, notes, 3D jumpscares, danger heartbeat, alarm, and the escape screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("ZooConfig"))
local remotes = ReplicatedStorage:WaitForChild("ZooRemotes")
local views = ReplicatedStorage:WaitForChild("MonsterViews")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local zoo = workspace:WaitForChild("Zoo")

local battery = Config.BatteryMax
local stamina = Config.StaminaMax
local flashlightOn = true
local introPlaying = false
local sprintHeld = false

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
local moneyLabel = label(gui, { Size = UDim2.fromOffset(300, 28), Position = UDim2.new(1, -320, 0, 86), TextXAlignment = Enum.TextXAlignment.Right,
	TextSize = 20, TextColor3 = Color3.fromRGB(120, 255, 120), Text = "" })
local center = label(gui, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromScale(0, 0.72), TextSize = 26, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })
local hideHint = label(gui, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromScale(0, 0.82), TextSize = 22, Text = "", TextColor3 = Color3.fromRGB(180, 200, 255) })
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

if UserInputService.TouchEnabled then
	local function mbtn(text, pos)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(90, 50)
		b.Position = pos
		b.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
		b.BackgroundTransparency = 0.3
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 16
		b.Text = text
		b.Parent = gui
		Instance.new("UICorner", b)
		return b
	end
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

-- Sounds ---------------------------------------------------------------------------
local function sound(id, volume)
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 1
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
	vp.LightDirection = Vector3.new(0, 1, -0.3) -- lit from below
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
		-- aim at the upper part of the body (the head is usually there)
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
		Text = livesLeft < 0 and "Infinite Lives - you wake up at the gate" or livesLeft > 0 and ("Lives left: " .. livesLeft) or "You were taken..." })
	task.wait(1.6)
	TweenService:Create(root, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(msg, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.wait(0.8)
	root:Destroy()
	scared = false
end)

-- Escape cutscene: you drive off in the company van, the Behemoth bursts out
-- of the trees and chases you down the road, nearly grabs the van... and
-- falls behind. Then the YOU ESCAPED screen.
local function playEscapeCutscene()
	local road = workspace:FindFirstChild("EscapeRoad")
	local origin = road and road:FindFirstChild("CutsceneOrigin")
	local vanTemplate = ReplicatedStorage:FindFirstChild("EscapeVan")
	if not (origin and vanTemplate) then
		return
	end
	local R = origin.Position
	-- brighter "moonlit" lighting just for the cutscene
	local savedLight = {}
	local cutLight = {
		Ambient = Color3.fromRGB(70, 72, 90),
		OutdoorAmbient = Color3.fromRGB(110, 115, 140),
		Brightness = 1.6,
		ExposureCompensation = 0.6,
	}
	for k, v in cutLight do
		savedLight[k] = Lighting[k]
		Lighting[k] = v
	end
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	local savedDensity = atmo and atmo.Density
	if atmo then
		atmo.Density = 0.18
	end
	gui.Enabled = false
	notePaper.Visible = false
	local fade = Instance.new("Frame")
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BorderSizePixel = 0
	fade.ZIndex = 10
	fade.Parent = overlay
	TweenService:Create(fade, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	local bars = {}
	for i, pos in { UDim2.fromScale(0, 0), UDim2.new(0, 0, 0.88, 0) } do
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(1, 0.12)
		bar.Position = pos
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.ZIndex = 9
		bar.Parent = overlay
		bars[i] = bar
	end

	local van = vanTemplate:Clone()
	van.Parent = workspace
	-- tire smoke for the drifts
	local smoke = {}
	for _, x in { -3.6, 3.6 } do
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(x, -4.2, 5)
		att.Parent = van.PrimaryPart
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(170, 170, 175))
		pe.Size = NumberSequence.new(2, 7)
		pe.Transparency = NumberSequence.new(0.5, 1)
		pe.Lifetime = NumberRange.new(1, 1.8)
		pe.Speed = NumberRange.new(2, 5)
		pe.SpreadAngle = Vector2.new(40, 40)
		pe.Rate = 40
		pe.Enabled = false
		pe.Parent = att
		table.insert(smoke, pe)
	end

	local mon = views:FindFirstChild("Behemoth")
	mon = mon and mon:Clone()
	local hip = mon and mon:GetAttribute("HipHeight") or 9
	local joints = {}
	local function pose(name, rx, ry, rz)
		local j = joints[name]
		if j then
			j.motor.C0 = j.base * CFrame.Angles(rx or 0, ry or 0, rz or 0)
		end
	end
	if mon then
		for _, d in mon:GetDescendants() do
			if d:IsA("Motor6D") then
				joints[d.Name] = { motor = d, base = d.C0 }
			end
		end
	end
	local claws = { "LClaw1", "LClaw2", "LClaw3", "RClaw1", "RClaw2", "RClaw3", "LThumbClaw", "RThumbClaw" }
	local function animate(t, state, runPhase)
		local s = math.sin
		if state == "peek" then
			pose("Right Shoulder", 0.3 + s(t * 2) * 0.05)
			pose("Left Shoulder", -0.3 - s(t * 2) * 0.05)
			pose("Neck", s(t * 7) * 0.08, s(t * 3) * 0.3)
		elseif state == "leap" then
			pose("Right Shoulder", 1.7)
			pose("Left Shoulder", -1.7)
			pose("Left Hip", 0.7)
			pose("Right Hip", -0.7)
			pose("Tail", 0.4)
		elseif state == "run" then
			pose("Left Hip", s(runPhase) * 0.8)
			pose("Right Hip", s(runPhase + math.pi) * 0.8)
			pose("Right Shoulder", 0.9 + s(runPhase + math.pi) * 0.5)
			pose("Left Shoulder", -0.9 - s(runPhase) * 0.5)
			pose("Tail", 0, s(runPhase) * 0.3)
			pose("Neck", 0.2)
		elseif state == "hang" then
			-- both arms clamped over the roof, claws digging in
			pose("Right Shoulder", 1.35 + s(t * 9) * 0.12)
			pose("Left Shoulder", -1.35 - s(t * 9 + 1) * 0.12)
			pose("RightLowerArm", 0.5 + s(t * 11) * 0.1)
			pose("LeftLowerArm", -0.5 - s(t * 11 + 2) * 0.1)
			for i, c in claws do
				pose(c, 0.5 + s(t * 14 + i) * 0.25)
			end
			-- legs dangling and swinging with the swerves
			pose("Left Hip", 0.5 + s(t * 5) * 0.5)
			pose("Right Hip", -0.5 + s(t * 5 + 1) * 0.5)
			pose("Tail", 0, s(t * 6) * 0.6)
			pose("Neck", 0.25 + s(t * 13) * 0.1, s(t * 4) * 0.15) -- head thrashing at the window
		elseif state == "fall" then
			pose("Right Shoulder", s(t * 12) * 1.6)
			pose("Left Shoulder", math.cos(t * 12) * 1.6)
			pose("Left Hip", s(t * 10) * 0.9)
			pose("Right Hip", math.cos(t * 10) * 0.9)
			pose("Tail", 0, s(t * 9) * 0.8)
		elseif state == "lying" then
			pose("Right Shoulder", 1.0)
			pose("Left Shoulder", -1.0)
			pose("Left Hip", 0)
			pose("Right Hip", 0)
		elseif state == "roar" then
			-- pushes up on its arms, head thrown back
			pose("Right Shoulder", 0.4 + s(t * 20) * 0.05)
			pose("Left Shoulder", -0.4 - s(t * 20) * 0.05)
			pose("Neck", -0.5 + s(t * 25) * 0.05)
			pose("Tail", 0, s(t * 8) * 0.4)
		end
	end
	if mon then
		mon.Parent = workspace
		local glow = Instance.new("PointLight")
		glow.Range = 28
		glow.Brightness = 2
		glow.Color = Color3.fromRGB(255, 215, 200)
		glow.Parent = mon.PrimaryPart
	end
	local function sfx(id, vol, pitch)
		if not id or id == "" then
			return
		end
		local snd = Instance.new("Sound")
		snd.SoundId = id
		snd.Volume = vol
		snd.PlaybackSpeed = pitch
		snd.Parent = gui
		snd:Play()
		task.delay(6, function()
			snd:Destroy()
		end)
	end
	local growlId = Config.MonsterSounds and Config.MonsterSounds.Behemoth.Id
	local cues = {
		{ 0.4, function() sfx(growlId, 2.5, 0.6) end }, -- behind the wall
		{ 1.2, function() sfx(growlId, 3.5, 0.7) end }, -- the leap
		{ 4.6, function() sfx(Config.Sounds.Jumpscare, 1.6, 0.8) end }, -- grabs the van
		{ 6.2, function() sfx(growlId, 3, 0.75) end },
		{ 7.4, function() sfx(growlId, 3.5, 0.55) end }, -- flung off
		{ 9.4, function() sfx(growlId, 3, 0.5) end }, -- the last roar
	}

	camera.CameraType = Enum.CameraType.Scriptable
	local t0 = os.clock()
	local dt = 1 / 60
	local vanZ, vanV, vanX, vanYaw = 15, 0, 0, 0
	local phase = 0
	local monFeet = R + Vector3.new(4, 0.4, 64) -- standing behind the zoo wall
	local monCF
	local runV = 0
	local leap2From
	local fallPos, fallVel, fallRot, fallSpin
	local shotDPos
	while true do
		local t = os.clock() - t0
		if t > 10.8 then
			break
		end
		for i = #cues, 1, -1 do
			if t >= cues[i][1] then
				cues[i][2]()
				table.remove(cues, i)
			end
		end

		-- the van ----------------------------------------------------------
		local target
		if t < 0.8 then
			target = 0
		elseif t < 2 then
			target = 30 * (t - 0.8) / 1.2
		elseif t < 7.6 then
			target = 30 + math.sin(t * 9) * 3
		else
			target = math.min(90, 30 + (t - 7.6) * 50)
		end
		vanV += (target - vanV) * math.min(1, dt * 4)
		vanZ -= vanV * dt
		-- swerving to shake it off, then one hard drift
		local driftSmoke = false
		if t > 5.4 and t < 7.4 then
			local k = math.clamp((t - 5.4) / 1.2, 0, 1)
			vanX = math.sin((t - 5.4) * 5) * 4 * k
			vanYaw = math.cos((t - 5.4) * 5) * 0.25 * k
			driftSmoke = true
		elseif t >= 7.4 and t < 8.8 then
			local u = (t - 7.4) / 1.4
			vanX = 6 * math.sin(u * math.pi) -- slides right, then recovers
			vanYaw = -0.6 * math.sin(u * math.pi)
			driftSmoke = u < 0.8
		else
			vanX += (0 - vanX) * math.min(1, dt * 3)
			vanYaw += (0 - vanYaw) * math.min(1, dt * 3)
		end
		for _, pe in smoke do
			pe.Enabled = driftSmoke
		end
		local vanCF = CFrame.new(R + Vector3.new(vanX, 4.8 + math.sin(t * 20) * 0.05 * math.min(1, vanV / 10), vanZ))
			* CFrame.Angles(0, vanYaw, math.clamp(-vanYaw * 0.15, -0.08, 0.08))
		van:PivotTo(vanCF)
		local rear = (vanCF * CFrame.new(0, -4.4, 8)).Position

		-- the Behemoth ------------------------------------------------------
		local moving = false
		if mon then
			if t < 1.2 then
				-- peeking over the wall, swaying
				monCF = CFrame.lookAt(monFeet + Vector3.new(0, hip, 0), monFeet + Vector3.new(0, hip, -1))
					* CFrame.Angles(math.sin(t * 2) * 0.05, math.sin(t * 1.3) * 0.2, 0)
			elseif t < 2.6 then
				-- leaps over the wall onto the road
				local u = (t - 1.2) / 1.4
				local from, to = R + Vector3.new(4, 0.4, 64), R + Vector3.new(0, 0.4, 2)
				monFeet = from:Lerp(to, u) + Vector3.new(0, 4 * 22 * u * (1 - u), 0)
				monCF = CFrame.lookAt(monFeet + Vector3.new(0, hip, 0), monFeet + Vector3.new(0, hip, -1)) * CFrame.Angles(-0.5 + u * 0.4, 0, 0)
			elseif t < 4.2 then
				-- sprints after the van
				runV += (55 - runV) * math.min(1, dt * 4)
				local aim = rear + Vector3.new(0, 0, 9)
				local to = Vector3.new(aim.X - monFeet.X, 0, aim.Z - monFeet.Z)
				if to.Magnitude > 0.5 then
					monFeet += to.Unit * math.min(to.Magnitude, runV * dt)
				end
				monFeet = Vector3.new(monFeet.X, R.Y + 0.4, monFeet.Z)
				moving = true
				local dir = to.Magnitude > 0.5 and to.Unit or Vector3.new(0, 0, -1)
				monCF = CFrame.lookAt(monFeet + Vector3.new(0, hip, 0), monFeet + Vector3.new(0, hip, 0) + dir) * CFrame.Angles(-0.15, 0, 0)
			elseif t < 7.4 then
				-- jumps on and hangs off the back doors
				local hold = vanCF * CFrame.new(math.sin(t * 6) * 0.6, hip * 0.5, 8 + 3.6) * CFrame.Angles(-0.3 + math.sin(t * 5) * 0.05, 0, math.sin(t * 4) * 0.12)
				if t < 4.6 then
					leap2From = leap2From or monCF
					local u = (t - 4.2) / 0.4
					monCF = leap2From:Lerp(hold, u) + Vector3.new(0, 4 * 5 * u * (1 - u), 0)
				else
					monCF = hold
				end
			else
				-- flung off by the drift: tumbles and lands face down
				if not fallPos then
					fallPos = monCF.Position
					fallVel = Vector3.new(-26, 10, vanV * 0.35)
					fallRot = monCF - monCF.Position
					fallSpin = 6
				end
				local groundY = R.Y + 0.4 + hip * 0.35
				fallVel += Vector3.new(0, -70 * dt, 0)
				fallPos += fallVel * dt
				if fallPos.Y <= groundY then
					fallPos = Vector3.new(fallPos.X, groundY, fallPos.Z)
					fallVel = Vector3.new(fallVel.X * 0.88, math.max(0, -fallVel.Y * 0.25), fallVel.Z * 0.88)
					fallSpin *= 0.9
				end
				if t < 9.2 then
					fallRot = fallRot * CFrame.Angles(fallSpin * dt, 0, fallSpin * 0.6 * dt)
					if fallSpin < 0.6 then
						-- settle face down
						local lying = CFrame.Angles(-1.35, 0, 0) -- face down, head toward the van
						fallRot = fallRot:Lerp(lying, math.min(1, dt * 3))
					end
				else
					-- pushes itself up and roars after the van
					local up = math.clamp((t - 9.2) / 0.8, 0, 1)
					local facing = CFrame.new() -- toward the van (-Z)
					fallRot = fallRot:Lerp(facing * CFrame.Angles(-1.35 + up * 1.0, 0, 0), math.min(1, dt * 4))
				end
				monCF = CFrame.new(fallPos) * fallRot
			end
			local state = t < 1.2 and "peek" or t < 2.6 and "leap" or t < 4.2 and "run" or t < 4.6 and "leap"
				or t < 7.4 and "hang" or (fallSpin and fallSpin > 0.6) and "fall" or t < 9.2 and "lying" or "roar"
			animate(t, state, phase)
			phase += dt * (moving and runV * 0.3 or 2)
			local bob = moving and math.abs(math.sin(phase)) * 1.2 or 0
			mon:PivotTo(monCF + Vector3.new(0, bob, 0))
		end

		-- camera ----------------------------------------------------------------
		local vanPos = vanCF.Position
		local monPos = monCF and monCF.Position or vanPos
		if t < 2.9 then
			-- wide: the van pulling out, the thing climbing over the wall behind it
			local focus = vanPos:Lerp(monPos + Vector3.new(0, hip * 0.6, 0), 0.5)
			camera.CFrame = CFrame.lookAt(R + Vector3.new(22, 8, -28), focus)
			camera.FieldOfView = 70
		elseif t < 4.4 then
			-- chase cam beside the van, looking back at it running
			camera.CFrame = CFrame.lookAt(vanPos + Vector3.new(-13, 6, -18), vanPos:Lerp(monPos + Vector3.new(0, hip * 0.6, 0), 0.6))
		elseif t < 7.35 then
			-- out the back window: it's right there
			local camPos = (vanCF * CFrame.new(0, 0.9, 7.3)).Position
			local intensity = t < 4.8 and 1 or 0.55
			local look = monPos + Vector3.new(0, hip * 0.5, 0)
			camera.CFrame = CFrame.lookAt(camPos, look)
				* CFrame.Angles((math.random() - 0.5) * 0.06 * intensity, (math.random() - 0.5) * 0.06 * intensity, (math.random() - 0.5) * 0.04 * intensity)
			camera.FieldOfView = 80
		else
			-- roadside: the drift, the fall, the van getting away
			shotDPos = shotDPos or (vanPos + Vector3.new(-26, 7, -38))
			local focus = vanPos:Lerp(monPos, 0.5)
			camera.CFrame = CFrame.lookAt(shotDPos, focus + Vector3.new(0, 3, 0))
			camera.FieldOfView = 65
		end
		if t > 9.9 and fade.BackgroundTransparency >= 1 then
			TweenService:Create(fade, TweenInfo.new(0.9), { BackgroundTransparency = 0 }):Play()
		end
		dt = RunService.RenderStepped:Wait()
	end
	camera.FieldOfView = 70
	for k, v in savedLight do
		Lighting[k] = v
	end
	if atmo then
		atmo.Density = savedDensity
	end
	van:Destroy()
	if mon then
		mon:Destroy()
	end
	for _, bar in bars do
		bar:Destroy()
	end
	task.delay(6, function()
		fade:Destroy()
	end)
end

remotes:WaitForChild("Escaped").OnClientEvent:Connect(function(secs, samples, total, difficulty, reward)
	local ok, err = pcall(playEscapeCutscene)
	if not ok then
		warn("Escape cutscene error: " .. tostring(err))
		camera.CameraType = Enum.CameraType.Custom
	end
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
		TextColor3 = Color3.fromRGB(120, 255, 140), Text = "YOU ESCAPED" })
	txt({ Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromScale(0, 0.5), TextSize = 26, Text = ("With the money. Time: %d:%02d   Difficulty: %s   Reward: $%d"):format(secs // 60, secs % 60, string.upper(difficulty or "Normal"), reward or 0) })
	txt({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromScale(0, 0.58), TextSize = 20, TextColor3 = Color3.fromRGB(170, 170, 170),
		Text = ("Money and all " .. (total or 6) .. " samples delivered to Wildcrest... but you left the gates open behind you. Something followed your van.") })
	txt({ Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromScale(0, 0.64), TextSize = 18, TextColor3 = Color3.fromRGB(230, 150, 80),
		Text = "CHAPTER 2: LAST CALL is now unlocked in the lobby." })
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

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		flashlightOn = not flashlightOn
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprintHeld = true
	end
end)
-- Free mouse: press M (or the button) to unlock the cursor so you can click
-- things; press again to go back to looking around. A visible Modal button is
-- what lets the mouse move freely in first person.
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
UserInputService.InputBegan:Connect(function(input, processed)
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
local checklist = label(gui, { Size = UDim2.new(0.4, 0, 0, 90), Position = UDim2.fromOffset(20, 108), TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, TextSize = 18, Text = "", TextColor3 = Color3.fromRGB(200, 200, 190) })
local function refreshChecklist()
	local fuses = ReplicatedStorage:GetAttribute("ZooFuses") or 0
	local power = ReplicatedStorage:GetAttribute("ZooPower") == true
	local phase = ReplicatedStorage:GetAttribute("ZooPhase") or 0
	local samples = ReplicatedStorage:GetAttribute("ZooSamples") or 0
	local need = Config.FusesNeeded or 3
	local mark = function(done) return done and "[x] " or "[ ] " end
	checklist.Size = UDim2.new(0.45, 0, 0, 110)
	checklist.Text = mark(power) .. (power and "Power restored" or ("Fuses " .. fuses .. "/" .. need .. " -> generator (lab)"))
		.. "\n" .. mark(phase >= 2) .. "Office keycard (lab Records)"
		.. "\n" .. mark(phase >= 3) .. "Money from the safe"
		.. "\n" .. mark(samples >= (Config.SamplesTotal or 6)) .. "Samples " .. samples .. "/" .. (Config.SamplesTotal or 6) .. " (3 in the lab + stun each monster)"
		.. "\n" .. "[ ] Escape through the front gate"
end
for _, a in { "ZooFuses", "ZooPower", "ZooPhase", "ZooSamples" } do
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
	local zap = Instance.new("Sound")
	zap.SoundId = Config.Sounds.Alarm
	zap.PlaybackSpeed = 3
	zap.Volume = 0.6
	zap.Parent = gui
	zap:Play()
	task.delay(0.35, function()
		zap:Destroy()
	end)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Q then
		fireStun()
	end
end)
if UserInputService.TouchEnabled then
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(90, 50)
	b.Position = UDim2.new(1, -200, 1, -270)
	b.BackgroundColor3 = Color3.fromRGB(30, 60, 100)
	b.BackgroundTransparency = 0.3
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.Text = "STUN"
	b.Parent = gui
	Instance.new("UICorner", b)
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
-- Infinite Lives game pass: buy button (hidden once you own it)
local MarketplaceService = game:GetService("MarketplaceService")
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
local function refreshMoney()
	local who = ReplicatedStorage:GetAttribute("MoneyCarrier") or ""
	if player:GetAttribute("CarryingMoney") then
		moneyLabel.Text = "$$$ You have the money"
	elseif who ~= "" then
		moneyLabel.Text = "$$$ " .. who .. " has the money"
	else
		moneyLabel.Text = ""
	end
end
ReplicatedStorage:GetAttributeChangedSignal("MoneyCarrier"):Connect(refreshMoney)
player:GetAttributeChangedSignal("CarryingMoney"):Connect(refreshMoney)
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
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local hidden = player:GetAttribute("Hidden") == true

	-- STALKER: lights fail near it
	local stalkerNear = false
	local chargingNear = false
	do
		local r = char:FindFirstChild("HumanoidRootPart")
		local mons = zoo:FindFirstChild("Monsters")
		local ab = Config.Abilities or {}
		if r and mons then
			for _, m in mons:GetChildren() do
				if m.PrimaryPart then
					local d = (m.PrimaryPart.Position - r.Position).Magnitude
					if m.Name == "Stalker" and d < ((ab.Stalker and ab.Stalker.InterferenceRange) or 32) then
						stalkerNear = true
					end
					if m.Name == "Behemoth" and m:GetAttribute("Charging") and d < 70 then
						chargingNear = true
					end
				end
			end
		end
		if stalkerNear and flashlightOn and battery > 0 then
			battery = math.max(0, battery - Config.BatteryDrain * dt * (((ab.Stalker and ab.Stalker.BatteryDrainMultiplier) or 4) - 1))
		end
	end
	if chargingNear and not scared then
		camera.CFrame *= CFrame.Angles((math.random() - 0.5) * 0.03, (math.random() - 0.5) * 0.03, (math.random() - 0.5) * 0.02)
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
	local inCutscene = not gui.Enabled
	local lightOn = flashlightOn and battery > 0 and not hidden and not inCutscene
	if lightOn and ((battery < 15 and math.random() < 0.08) or (stalkerNear and math.random() < 0.35)) then
		lightOn = false
	end
	spot.Enabled = lightOn
	glow.Enabled = lightOn
	local ftier = Config.ShopTier and Config.ShopTier("Flashlight", player:GetAttribute("FlashTier") or 1)
	spot.Brightness = (ftier and ftier.Brightness or 3.5) * math.clamp(battery / 30, 0.35, 1)
	spot.Range = ftier and ftier.Range or 60
	spot.Angle = ftier and ftier.Angle or 50
	local beam = ({ ice = Color3.fromRGB(170, 220, 255), uv = Color3.fromRGB(190, 120, 255), red = Color3.fromRGB(255, 110, 100) })[player:GetAttribute("Up_FlashSkin") or ""]
	spot.Color = beam or Color3.fromRGB(255, 245, 225)
	glow.Color = spot.Color
	batteryFill.Size = UDim2.fromScale(battery / Config.BatteryMax, 1)

	local moving = hum.MoveDirection.Magnitude > 0.1 and not hidden
	local sprinting = sprintHeld and moving and stamina > 1
	if sprinting then
		local sh = Config.ShopTier and Config.ShopTier("Shoes", player:GetAttribute("ShoeTier") or 1)
		stamina = math.max(0, stamina - Config.StaminaDrain * dt / (sh and sh.Stamina or 1))
	else
		stamina = math.min(Config.StaminaMax, stamina + Config.StaminaRegen * dt * (moving and 0.6 or 1))
	end
	if player:GetAttribute("CarryingMoney") then
		hum.WalkSpeed = sprinting and Config.CarrySprintSpeed or Config.CarryWalkSpeed
	else
		hum.WalkSpeed = sprinting and Config.SprintSpeed or Config.WalkSpeed
	end
	hum.WalkSpeed *= (player:GetAttribute("AdminSpeed") or 1)
	staminaFill.Size = UDim2.fromScale(stamina / Config.StaminaMax, 1)
	staminaFill.BackgroundColor3 = stamina < 25 and Color3.fromRGB(255, 120, 80) or Color3.fromRGB(120, 200, 255)

	local state = { Sprinting = sprinting, Moving = moving, Flashlight = flashlightOn and battery > 0 }
	if os.clock() > sendAt and (state.Sprinting ~= lastSent.Sprinting or state.Moving ~= lastSent.Moving or state.Flashlight ~= lastSent.Flashlight) then
		sendAt = os.clock() + 0.15
		lastSent = state
		remotes.State:FireServer(state)
	end

	local nearest, chased = math.huge, false
	local root = char:FindFirstChild("HumanoidRootPart")
	local monsters = zoo:FindFirstChild("Monsters")
	if root and monsters then
		for _, m in monsters:GetChildren() do
			if m.PrimaryPart then
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
	if chased and not scared then
		camera.CFrame *= CFrame.Angles(math.rad(math.random() - 0.5) * 0.4, math.rad(math.random() - 0.5) * 0.4, 0)
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
local CollectionService = game:GetService("CollectionService")
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

-- Security radar: outline monsters + key items through walls for a few seconds.
local radarItems = {
	Fuse = { "FUSE", Color3.fromRGB(255, 170, 50) },
	Keycard = { "KEYCARD", Color3.fromRGB(80, 170, 255) },
	Sample = { "SAMPLE", Color3.fromRGB(110, 255, 150) },
	StunGun = { "STUN GUN", Color3.fromRGB(120, 200, 255) },
	StunCartridge = { "CARTRIDGE", Color3.fromRGB(120, 200, 255) },
	MoneyBag = { "MONEY", Color3.fromRGB(120, 255, 120) },
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
			bb.Parent = player.PlayerGui -- (a BillboardGui inside a ScreenGui doesn't render)
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
	local mons = zoo:FindFirstChild("Monsters")
	if mons then
		for _, m in mons:GetChildren() do
			mark(m, Color3.fromRGB(255, 40, 40), string.upper(m.Name), true)
		end
	end
	local items = zoo:FindFirstChild("Items")
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
	-- radar sweep sound + green screen pulse
	local ping = Instance.new("Sound")
	ping.SoundId = Config.Sounds.Alarm
	ping.PlaybackSpeed = 2.2
	ping.Volume = 0.5
	ping.Parent = gui
	ping:Play()
	task.delay(0.6, function()
		ping:Destroy()
	end)
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
	local radar = zoo:WaitForChild("RadarStation", 10)
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
			status.Text = "PARK RADAR\nOFFLINE"
			status.TextColor3 = Color3.fromRGB(120, 120, 120)
		elseif status then
			if active then
				status.Text = "PARK RADAR\nSCANNING..."
				status.TextColor3 = Color3.fromRGB(255, 230, 90)
			elseif now < readyAt then
				status.Text = ("PARK RADAR\nRECHARGING %ds"):format(math.ceil(readyAt - now))
				status.TextColor3 = Color3.fromRGB(255, 90, 80)
			else
				status.Text = "PARK RADAR\nREADY"
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
	stroke.Color = Color3.fromRGB(120, 30, 30)
	stroke.Thickness = 2
	stroke.Parent = picker
	label(picker, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 10), Font = Enum.Font.Creepster, TextScaled = true,
		TextColor3 = Color3.fromRGB(230, 210, 170), Text = "CHOOSE YOUR NIGHT" })
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
		b.Modal = true -- frees the mouse in first person
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
	close.Modal = true -- frees the mouse while shopping
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

-- The broken carousel turns by itself, stuttering and stopping now and then.
task.spawn(function()
	local car = zoo:WaitForChild("Expansion", 10)
	car = car and car:FindFirstChild("Carousel")
	local spinner = car and car:FindFirstChild("Spinner")
	if not spinner then
		return
	end
	local home = spinner:GetPivot()
	local angle, speed, target = 0, 0, 0.25
	local nextChange = os.clock() + 4
	RunService.Heartbeat:Connect(function(dt)
		if os.clock() > nextChange then
			target = math.random() < 0.35 and 0 or (0.15 + math.random() * 0.3)
			nextChange = os.clock() + 3 + math.random() * 6
		end
		speed += (target - speed) * math.min(1, dt * 0.8)
		if speed > 0.005 then
			angle += speed * dt
			spinner:PivotTo(home * CFrame.Angles(0, angle, 0))
		end
	end)
end)

-- Porta-potty signs show OCCUPIED (red) while someone is hiding inside.
for _, spot in game:GetService("CollectionService"):GetTagged("HideSpot") do
	local sign = spot:FindFirstChild("OccupiedSign")
	if sign then
		local function refresh()
			sign.Color = spot:GetAttribute("Occupant") and Color3.fromRGB(200, 30, 30) or Color3.fromRGB(30, 160, 60)
		end
		spot:GetAttributeChangedSignal("Occupant"):Connect(refresh)
		refresh()
	end
end

-- INTRO: the briefing. Director Marsh sends you (a Wildcrest employee) in for the money.
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
	-- the zoo's fog would swallow the office: clear it while we're indoors
	local atmo = game:GetService("Lighting"):FindFirstChildOfClass("Atmosphere")
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
	local function P(x, y, z)
		return (O * CFrame.new(x, y, z)).Position
	end
	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BorderSizePixel = 0
	black.ZIndex = 50
	black.Parent = overlay
	local bars = {}
	for i = 1, 2 do
		local b = Instance.new("Frame")
		b.Size = UDim2.fromScale(1, i == 2 and 0.16 or 0.1)
		b.Position = i == 2 and UDim2.fromScale(0, 0.84) or UDim2.fromScale(0, 0)
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
		{ 4.6, "Ah. You're the night shift. Come in." },
		{ 7, "Three weeks ago our zoo had an... incident. We shut it down overnight. Nobody's been back inside since." },
		{ 12.5, "Problem is, the last day's takings are still in the Cash Office safe. A LOT of our money." },
		{ 18, "Your job: go in, open that safe, and bring the money back to the van. That's it." },
		{ 23.5, "If the power's out, there's a generator under the Reptile House. Ignore whatever you find down there." },
		{ 28.5, "And whatever you hear in the dark... it's just old pipes. Understood?" },
		{ 33, "Get the money. Get out. And lock every gate behind you." },
		{ 37, "...EVERY gate." },
	}
	local curLine, curStart = nil, 0
	local t0 = os.clock()
	local fadeOutAt, arrivalAt, endAt = 39.6, 40.6, 47
	local shakeUntil = 0
	local start = zoo:FindFirstChild("Start")
	local gatePos = start and start.Position or Vector3.new(0, 30, -662)
	while not skipped do
		local t = os.clock() - t0
		if t > endAt then
			break
		end
		if t < 3 then
			card.Text = "WILDCREST CORP. HEADQUARTERS"
			cardSub.Text = "Three weeks after the zoo closed"
		elseif t < arrivalAt then
			card.Text, cardSub.Text = "", ""
		elseif t < 44 then
			card.Text = "CHAPTER 1: CLOSING TIME"
		else
			card.Text = ""
		end
		if t < 3 then
			black.BackgroundTransparency = 0
		elseif t < 4 then
			black.BackgroundTransparency = t - 3
		elseif t > fadeOutAt and t < arrivalAt then
			black.BackgroundTransparency = 1 - (t - fadeOutAt)
		elseif t >= arrivalAt and t < 44 then
			black.BackgroundTransparency = 0.35
		elseif t > endAt - 1 then
			black.BackgroundTransparency = math.max(0, endAt - t)
		else
			black.BackgroundTransparency = 1
		end
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
			if flash then
				flash.Brightness = (t > 3.6 and t < 3.75) and 6 or ((t > 3.85 and t < 3.95) and 4 or ((t > 25 and t < 25.12) and 5 or 0))
			end
			if man and manRoot then
				local turn = math.clamp((t - 4.6) / 1.2, 0, 1)
				turn = turn * turn * (3 - 2 * turn)
				man:PivotTo(manHome * CFrame.Angles(0, math.pi * turn, 0))
				local talking = curLine and t - curStart < #dialogue[curLine][2] / 38 + 0.3
				local nod = talking and math.sin(t * 7) * 0.05 or 0
				local look = (t > 18 and t < 21.5) and 0.7 or 0
				if neck then
					neck.Transform = CFrame.Angles(nod, look, 0)
				end
				local point = (t > 19 and t < 22) and math.clamp((t - 19) * 3, 0, 1) or 0 -- points at the monitor
				local lean = t > 36.5 and math.clamp((t - 36.5) * 2, 0, 1) or 0
				if waist then
					waist.Transform = CFrame.Angles(-0.3 * lean, look * 0.4, 0)
				end
				if rs then
					rs.Transform = CFrame.Angles(math.rad(80) * point + math.rad(45) * lean, 0, math.rad(25) * point)
				end
				if lsh then
					lsh.Transform = CFrame.Angles(math.rad(45) * lean, 0, 0)
				end
			end
			local face = manRoot and (manRoot.Position + Vector3.new(0, 2.2, 0)) or P(0, 6, -8)
			local camCF
			if t < 6.5 then
				camCF = CFrame.lookAt(P(9, 7.5, 10) + Vector3.new(-t * 0.3, 0, 0), face - Vector3.new(0, 1, 0))
			elseif t < 12.5 then
				local k = (t - 6.5) / 6
				camCF = CFrame.lookAt(P(0, 5.6, 4 - k * 1.5), face)
			elseif t < 18 then
				camCF = CFrame.lookAt(P(-9, 8, -1), face) -- wide, the evidence board
			elseif t < 23.5 then
				camCF = CFrame.lookAt(P(1.2, 5.6, -2.2), P(3, 5.5, -5)) -- the monitor: the safe
			elseif t < 28.5 then
				camCF = CFrame.lookAt(P(6.5, 3.4, -5.5), face + Vector3.new(0, 0.3, 0))
			elseif t < 33 then
				local k = (t - 28.5) / 4.5
				camCF = CFrame.lookAt(P(-3 + k, 5.4, 2), face)
			else
				local k = math.clamp((t - 33) / 5, 0, 1)
				camCF = CFrame.lookAt(P(0, 5.2, 1.5 - k * 2.5), face)
			end
			camera.CFrame = camCF
			camera.FieldOfView = 60
		else
			-- arriving at the zoo gate at night
			if atmo and savedDensity then
				atmo.Density = savedDensity
			end
			local u = t - arrivalAt
			camera.CFrame = CFrame.lookAt(gatePos + Vector3.new(-14 + u * 2.5, 9 - u * 0.3, 34 - u * 2), gatePos + Vector3.new(0, 8, -60))
			camera.FieldOfView = 65
			if u > 3.5 then
				line.Text = "Wildcrest Zoo. Closed. Quiet. Too quiet."
			end
		end
		RunService.Heartbeat:Wait() -- (keeps going even if the window isn't drawing)
	end
	if atmo and savedDensity then
		atmo.Density = savedDensity
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
	notice("The van drops you at the gate. It's quiet. Too quiet.", nil, 4)
end

task.spawn(function()
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

-- Objective marker: a small diamond + distance on the next FIXED place to go (items you have to
-- search for are left to the radar). [H] hides it.
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
		local cur = zoo
		for _, n in path do
			cur = cur and cur:FindFirstChild(n)
		end
		return cur
	end
	local function target()
		local RS = ReplicatedStorage
		local phase = RS:GetAttribute("ZooPhase") or 0
		if phase < 1 or not player:GetAttribute("InGame") then
			return nil
		end
		local power = RS:GetAttribute("ZooPower") == true
		if not power and (RS:GetAttribute("ZooFuses") or 0) >= (Config.FusesNeeded or 3) then
			return find({ "ResearchLab", "Furniture", "Generator" }), "GENERATOR (LAB)"
		end
		if phase == 2 then
			local door = find({ "Buildings", "Office", "KeycardDoor" })
			if door and not door:GetAttribute("Open") then
				return power and door or nil, "CASH OFFICE"
			end
			return find({ "Buildings", "Office", "Safe", "SafeDoor" }), "SAFE"
		end
		if phase >= 3 then
			if (RS:GetAttribute("ZooSamples") or 0) >= (Config.SamplesTotal or 6) then
				return find({ "FrontGate", "ExitZone" }), "FRONT GATE"
			end
			return nil
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
