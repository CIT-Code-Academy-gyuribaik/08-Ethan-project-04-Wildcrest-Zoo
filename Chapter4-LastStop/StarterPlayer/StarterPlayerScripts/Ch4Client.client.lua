-- CHAPTER 4: LAST STOP - client (framework from chapter 3)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Config = require(ReplicatedStorage:WaitForChild("HQConfig"))
local remotes = ReplicatedStorage:WaitForChild("HQRemotes")
local level = workspace:WaitForChild("Tower")
local views = ReplicatedStorage:WaitForChild("MonsterViews")
local RS = ReplicatedStorage

local gui = Instance.new("ScreenGui")
gui.Name = "HQHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")
local overlay = Instance.new("ScreenGui")
overlay.Name = "HQOverlay"
overlay.ResetOnSpawn = false
overlay.IgnoreGuiInset = true
overlay.DisplayOrder = 10
overlay.Parent = player.PlayerGui

local FONT = Enum.Font.SpecialElite
local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = Color3.fromRGB(235, 230, 220)
	l.TextStrokeTransparency = 0.5
	l.TextSize = 20
	for k, v in props do
		l[k] = v
	end
	l.Parent = parent
	return l
end
local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do
		f[k] = v
	end
	f.Parent = parent
	return f
end
local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = o
end
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
	game:GetService("Debris"):AddItem(s, 10)
	return s
end

-- HUD ----------------------------------------------------------------------------------
local objective = label(gui, { Size = UDim2.new(0.6, 0, 0, 56), Position = UDim2.new(0, 24, 0, 18), TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, TextSize = 22, Text = "" })
local checklist = label(gui, { Size = UDim2.new(0, 420, 0, 230), Position = UDim2.new(0, 24, 0, 80), TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, TextSize = 17, Text = "", TextColor3 = Color3.fromRGB(220, 220, 210) })
local livesLabel = label(gui, { Size = UDim2.new(0, 200, 0, 30), Position = UDim2.new(1, -224, 0, 18), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 24,
	TextColor3 = Color3.fromRGB(255, 90, 90), Text = "" })
local diffLabel = label(gui, { Size = UDim2.new(0, 200, 0, 24), Position = UDim2.new(1, -224, 0, 48), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 18,
	Font = Enum.Font.GothamBlack, Text = "" })
local stunLabel = label(gui, { Size = UDim2.new(0, 360, 0, 24), Position = UDim2.new(0, 24, 1, -118), TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(140, 210, 255), Text = "" })
local flashLabel = label(gui, { Size = UDim2.new(0, 360, 0, 22), Position = UDim2.new(0, 24, 1, -94), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 17, Text = "FLASHLIGHT [F]   HIDE/LEAVE [E]" })
local staminaBack = frame(gui, { Size = UDim2.new(0, 300, 0, 10), Position = UDim2.new(0, 24, 1, -64), BackgroundColor3 = Color3.fromRGB(30, 30, 34) })
corner(staminaBack, 5)
local staminaFill = frame(staminaBack, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 200, 255) })
corner(staminaFill, 5)
label(gui, { Size = UDim2.new(0, 300, 0, 18), Position = UDim2.new(0, 24, 1, -84), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 15, Text = "STAMINA [SHIFT]" })
-- broadcast bar
local bcBack = frame(gui, { Size = UDim2.new(0.42, 0, 0, 22), Position = UDim2.new(0.29, 0, 0, 92), BackgroundColor3 = Color3.fromRGB(20, 20, 24), Visible = false })
corner(bcBack, 6)
local bcFill = frame(bcBack, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 200, 70) })
corner(bcFill, 6)
local bcText = label(bcBack, { Size = UDim2.fromScale(1, 1), TextSize = 16, Font = Enum.Font.GothamBlack, Text = "BROADCAST 0%", ZIndex = 3 })
-- notices
local noticeHolder = frame(gui, { Size = UDim2.new(0.7, 0, 0, 200), Position = UDim2.new(0.15, 0, 0.62, 0), BackgroundTransparency = 1 })
local nl = Instance.new("UIListLayout") nl.VerticalAlignment = Enum.VerticalAlignment.Bottom nl.HorizontalAlignment = Enum.HorizontalAlignment.Center nl.Padding = UDim.new(0, 4) nl.Parent = noticeHolder
local function notice(text, color, dur)
	local l = label(noticeHolder, { Size = UDim2.new(1, 0, 0, 30), TextSize = 22, Text = text, TextColor3 = color or Color3.fromRGB(240, 235, 220), TextWrapped = true })
	task.delay(dur or 4, function()
		TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.7)
		l:Destroy()
	end)
end
remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text, color)
	notice(text, color)
end)
-- PA / dialogue box
local paBox = frame(overlay, { Size = UDim2.new(0.56, 0, 0, 70), Position = UDim2.new(0.22, 0, 0.8, 0), BackgroundColor3 = Color3.fromRGB(10, 10, 12), BackgroundTransparency = 0.25, Visible = false, ZIndex = 20 })
corner(paBox, 8)
local paWho = label(paBox, { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.new(0, 10, 0, 4), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Color3.fromRGB(255, 90, 80), ZIndex = 21 })
local paText = label(paBox, { Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0, 10, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextSize = 20, ZIndex = 21 })
local paToken = 0
local function say(who, text, dur)
	paToken += 1
	local t = paToken
	paWho.Text = who
	paText.Text = text
	paBox.Visible = true
	task.delay(dur or 4.5, function()
		if paToken == t then
			paBox.Visible = false
		end
	end)
end
remotes:WaitForChild("PA").OnClientEvent:Connect(function(line, who)
	say(who == "MARSH" and "DIRECTOR MARSH (PA)" or who, line, 5)
	sound("", 0.4, 0.8)
end)

local function checklistText()
	local phase = RS:GetAttribute("Phase") or 0
	local function box(done)
		return done and "[x] " or "[ ] "
	end
	if phase >= 22 then
		return table.concat({
			"LAST STOP",
			box(phase >= 23) .. "Board the last train",
			box(phase >= 24) .. "Uncouple the cars",
			box(false) .. "Check the driver's cab",
		}, "\n")
	elseif phase >= 20 then
		return table.concat({
			"CONTROL CENTER",
			box(phase >= 21) .. "Switch tracks + restore power",
			box(phase >= 22) .. "Get to Platform 9",
		}, "\n")
	elseif phase >= 18 then
		return table.concat({
			"THE SEWERS",
			box(phase >= 19) .. ("Close the valves %d/3"):format(RS:GetAttribute("Valves") or 0),
			box(phase >= 20) .. "Climb out",
		}, "\n")
	elseif phase >= 14 then
		return table.concat({
			"CONSTRUCTION STATION",
			box(phase >= 15) .. "Start the generator",
			box(phase >= 17) .. "Cross the walkway",
			box(phase >= 18) .. "Down the sewer hatch",
		}, "\n")
	end
	if phase >= 11 then
		return table.concat({
			"THE DARK TUNNEL",
			box(phase >= 12) .. "Follow the tunnel",
			box(phase >= 13) .. "Hide from IT",
			box(false) .. "Reach the end of the tunnel",
			"     (trains: get into an ALCOVE!)",
		}, "\n")
	end
	if phase >= 7 then
		return table.concat({
			"OLD TOWN STATION",
			box(RS:GetAttribute("StationKey")) .. "Find the station key",
			box(phase >= 8) .. "Open the service gate",
			box(phase >= 10) .. "Cut the track power",
			box(false) .. "Into the tunnel",
		}, "\n")
	end
	return table.concat({
		"THE RAID",
		box(phase >= 2) .. "Get out of your apartment",
		box(phase >= 3) .. "Reach the stairs",
		box(phase >= 4) .. "Get off the stairs (floor 10)",
		box(phase >= 5) .. "Down the elevator shaft",
		box(phase >= 6) .. "Sneak out of the lobby",
		box(phase >= 7) .. "Reach the subway",
	}, "\n")
end
local function refreshHUD()
	objective.Text = RS:GetAttribute("Objective") or ""
	checklist.Text = (RS:GetAttribute("Phase") or 0) >= 1 and checklistText() or ""
	local lives = player:GetAttribute("Lives")
	livesLabel.Text = lives and (player:GetAttribute("AdminGod") and "GOD MODE" or (player:GetAttribute("InfiniteLives") and "INFINITE LIVES" or string.rep("<3 ", math.max(lives, 0)))) or ""
	local d = RS:GetAttribute("Difficulty") or ""
	diffLabel.Text = d:upper()
	local dc = Config.Difficulties[d]
	diffLabel.TextColor3 = dc and dc.Color or Color3.new(1, 1, 1)
	stunLabel.Text = player:GetAttribute("HasStunner") and ("STUN GUN [Q]: %d charges"):format(player:GetAttribute("StunCharges") or 0) or ""
	local b = RS:GetAttribute("Broadcast") or 0
	bcBack.Visible = (RS:GetAttribute("Phase") or 0) >= 5 and b > 0
	bcFill.Size = UDim2.fromScale(math.clamp(b / 100, 0, 1), 1)
	bcText.Text = RS:GetAttribute("SignalCut") and "BROADCAST - SIGNAL LOST" or (RS:GetAttribute("BroadcastStalled") and ("BROADCAST %d%% - STAY NEAR THE CONSOLE!"):format(b) or ("BROADCAST %d%%"):format(b))
	bcFill.BackgroundColor3 = RS:GetAttribute("SignalCut") and Color3.fromRGB(200, 40, 40) or Color3.fromRGB(255, 200, 70)
end
for _, a in { "Valves", "StationKey", "Objective", "Phase", "Evidence", "EvidenceNeeded", "Keycard1", "Keycard2", "CellsFreed", "SignalCut", "Tapes", "Difficulty", "Broadcast", "BroadcastStalled" } do
	RS:GetAttributeChangedSignal(a):Connect(refreshHUD)
end
for _, a in { "Lives", "StunCharges", "HasStunner", "AdminGod", "InfiniteLives" } do
	player:GetAttributeChangedSignal(a):Connect(refreshHUD)
end
refreshHUD()

-- MOVEMENT / FLASHLIGHT -----------------------------------------------------------------
local minigameOpen = false
local cutscenePlaying = false
local stamina = Config.StaminaMax
local sprintHeld = false
local flashlightOn = false
local flash
-- the flashlight rides on the camera (a light inside the head gets blocked by big hair/hats)
local flashRig = Instance.new("Part")
flashRig.Name = "FlashlightRig"
flashRig.Anchored, flashRig.CanCollide, flashRig.CanQuery, flashRig.CanTouch = true, false, false, false
flashRig.Transparency = 1
flashRig.Size = Vector3.new(0.2, 0.2, 0.2)
flashRig.Parent = workspace.CurrentCamera
flash = Instance.new("SpotLight")
flash.Name = "Flashlight"
flash.Angle = 50
flash.Range = 60
flash.Brightness = 3
flash.Color = Color3.fromRGB(255, 244, 220)
flash.Shadows = true
flash.Face = Enum.NormalId.Front
flash.Parent = flashRig
local glowNear = Instance.new("PointLight")
glowNear.Range = 9
glowNear.Brightness = 0.4
glowNear.Color = Color3.fromRGB(255, 240, 215)
glowNear.Parent = flashRig
RunService:BindToRenderStep("FlashlightFollow", Enum.RenderPriority.Camera.Value + 5, function()
	flashRig.CFrame = camera.CFrame * CFrame.new(0.6, -0.5, -0.4)
end)
local FLASH_SKINS = { [""] = Color3.fromRGB(255, 244, 220), ice = Color3.fromRGB(170, 220, 255), uv = Color3.fromRGB(190, 120, 255), red = Color3.fromRGB(255, 110, 100) }
local function applyFlashUpgrades()
	local tier = player:GetAttribute("Up_Flash") or 0
	flash.Brightness = 3 + tier * 0.9
	flash.Range = 60 + tier * 15
	flash.Angle = 50 + tier * 6
	flash.Color = FLASH_SKINS[player:GetAttribute("Up_FlashSkin") or ""] or FLASH_SKINS[""]
	glowNear.Color = flash.Color
end
for _, a in { "Up_Flash", "Up_FlashSkin" } do
	player:GetAttributeChangedSignal(a):Connect(applyFlashUpgrades)
end
applyFlashUpgrades()
local function ensureFlash()
	local on = flashlightOn and not cutscenePlaying
	flash.Enabled = on
	glowNear.Enabled = on
end
local lastSent = {}
local sendAt = 0
RunService.Heartbeat:Connect(function(dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local moving = hum.MoveDirection.Magnitude > 0.1 and not player:GetAttribute("Hidden")
	local sprinting = sprintHeld and moving and stamina > 1 and not minigameOpen
	local drainMul = player:GetAttribute("Up_Sprinter") and 0.7 or 1 -- Sprinter skill
	if sprinting then
		stamina = math.max(0, stamina - Config.StaminaDrain * drainMul * dt)
	else
		stamina = math.min(Config.StaminaMax, stamina + Config.StaminaRegen * dt * (moving and 0.6 or 1) / drainMul)
	end
	local speed = sprinting and Config.SprintSpeed or Config.WalkSpeed
	if minigameOpen or cutscenePlaying then
		speed = 0
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local wading = hrp and hrp.Position.Y < -50 and hrp.Position.Y > -62 -- knee-deep sewer water
	hum.WalkSpeed = speed * (player:GetAttribute("AdminSpeed") or 1) * (wading and 0.62 or 1)
	staminaFill.Size = UDim2.fromScale(stamina / Config.StaminaMax, 1)
	ensureFlash()
	if os.clock() > sendAt and (lastSent.s ~= sprinting or lastSent.m ~= moving or lastSent.f ~= flashlightOn) then
		sendAt = os.clock() + 0.25
		lastSent = { s = sprinting, m = moving, f = flashlightOn }
		remotes.State:FireServer({ Sprinting = sprinting, Moving = moving, Flashlight = flashlightOn })
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprintHeld = true
	end
	if processed or minigameOpen or cutscenePlaying then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		flashlightOn = not flashlightOn
		sound("", 0.5, 1.4)
	elseif input.KeyCode == Enum.KeyCode.Q then
		if player:GetAttribute("HasStunner") then
			remotes.Stun:FireServer(camera.CFrame.LookVector)
			sound("", 0.8, 1.6)
		end
	elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space then
		if player:GetAttribute("Hidden") then
			remotes.LeaveHide:FireServer()
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprintHeld = false
	end
end)

-- NOTES ---------------------------------------------------------------------------------
local paper = frame(overlay, { Size = UDim2.new(0, 460, 0, 380), Position = UDim2.new(0.5, -230, 0.5, -190), BackgroundColor3 = Color3.fromRGB(232, 222, 196), Visible = false, ZIndex = 30 })
corner(paper, 4)
local paperTitle = label(paper, { Size = UDim2.new(1, -40, 0, 40), Position = UDim2.new(0, 20, 0, 14), TextColor3 = Color3.fromRGB(40, 30, 20), TextStrokeTransparency = 1, TextSize = 24, ZIndex = 31 })
local paperBody = label(paper, { Size = UDim2.new(1, -40, 1, -110), Position = UDim2.new(0, 20, 0, 60), TextColor3 = Color3.fromRGB(40, 30, 20), TextStrokeTransparency = 1, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 20, ZIndex = 31 })
local paperClose = Instance.new("TextButton")
paperClose.Size = UDim2.new(0, 140, 0, 34) paperClose.Position = UDim2.new(0.5, -70, 1, -46) paperClose.Text = "Close" paperClose.Font = Enum.Font.GothamBold paperClose.TextSize = 18
paperClose.BackgroundColor3 = Color3.fromRGB(60, 50, 40) paperClose.TextColor3 = Color3.new(1, 1, 1) paperClose.ZIndex = 32 paperClose.Parent = paper
corner(paperClose, 6)
paperClose.MouseButton1Click:Connect(function()
	paper.Visible = false
end)
remotes:WaitForChild("ShowNote").OnClientEvent:Connect(function(title, body)
	paperTitle.Text = title
	paperBody.Text = body
	paper.Visible = true
	sound("", 0.6, 1.2)
end)

-- JUMPSCARE -----------------------------------------------------------------------------
local scare = Instance.new("ViewportFrame")
scare.Size = UDim2.fromScale(1, 1)
scare.BackgroundColor3 = Color3.new(0, 0, 0)
scare.BackgroundTransparency = 0.2
scare.Visible = false
scare.ZIndex = 50
scare.Parent = overlay
local scareCam = Instance.new("Camera")
scareCam.Parent = scare
scare.CurrentCamera = scareCam
local scareText = label(overlay, { Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromScale(0, 0.8), Font = Enum.Font.Creepster, TextScaled = true, TextColor3 = Color3.fromRGB(255, 60, 50), Text = "", Visible = false, ZIndex = 51 })
remotes:WaitForChild("Caught").OnClientEvent:Connect(function(kind, lives)
	scare:ClearAllChildren()
	scareCam = Instance.new("Camera")
	scareCam.Parent = scare
	scare.CurrentCamera = scareCam
	local v = views:FindFirstChild(kind)
	if v then
		local m = v:Clone()
		m:PivotTo(CFrame.new())
		m.Parent = scare
		local head = m:FindFirstChild("Head")
		local target = head and head.Position or Vector3.new(0, 4, 0)
		scareCam.CFrame = CFrame.lookAt(target + Vector3.new(0, 0, -2.6), target)
	end
	scare.Visible = true
	scareText.Visible = true
	scareText.Text = kind == "Train" and "HIT BY THE TRAIN!" or kind == "Guard" and "TASERED!" or (kind == "Marsh" and "\"GOTCHA.\"" or "IT GOT YOU")
	sound(Config.Sounds.Jumpscare, 2)
	local t0 = os.clock()
	while os.clock() - t0 < 1.4 do
		scareCam.CFrame = scareCam.CFrame * CFrame.new((math.random() - 0.5) * 0.08, (math.random() - 0.5) * 0.08, 0.02)
		RunService.Heartbeat:Wait()
	end
	scare.Visible = false
	scareText.Visible = false
end)

-- MINI-GAMES ----------------------------------------------------------------------------
local mgRoot = frame(overlay, { Size = UDim2.new(0, 520, 0, 420), Position = UDim2.new(0.5, -260, 0.5, -210), BackgroundColor3 = Color3.fromRGB(16, 18, 22), Visible = false, ZIndex = 40 })
corner(mgRoot, 10)
local mgStroke = Instance.new("UIStroke") mgStroke.Color = Color3.fromRGB(255, 200, 90) mgStroke.Thickness = 2 mgStroke.Parent = mgRoot
local mgTitle = label(mgRoot, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 8), Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = Color3.fromRGB(255, 210, 110), ZIndex = 41 })
local mgHint = label(mgRoot, { Size = UDim2.new(1, -30, 0, 40), Position = UDim2.new(0, 15, 0, 46), TextWrapped = true, TextSize = 17, ZIndex = 41 })
local mgArea = frame(mgRoot, { Size = UDim2.new(1, -30, 1, -150), Position = UDim2.new(0, 15, 0, 92), BackgroundTransparency = 1, ZIndex = 41 })
local mgStatus = label(mgRoot, { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 1, -62), TextSize = 18, ZIndex = 41, Text = "" })
local mgQuit = Instance.new("TextButton")
mgQuit.Size = UDim2.new(0, 120, 0, 30) mgQuit.Position = UDim2.new(0.5, -60, 1, -36) mgQuit.Text = "Back away" mgQuit.Font = Enum.Font.GothamBold mgQuit.TextSize = 15
mgQuit.BackgroundColor3 = Color3.fromRGB(70, 40, 40) mgQuit.TextColor3 = Color3.new(1, 1, 1) mgQuit.ZIndex = 42 mgQuit.Parent = mgRoot
corner(mgQuit, 6)
local mgKind, mgToken = nil, 0
local mgConns = {}
local function mgClean()
	for _, c in mgConns do
		c:Disconnect()
	end
	table.clear(mgConns)
	mgArea:ClearAllChildren()
end
local function mgFinish(ok, payload)
	if not mgKind then
		return
	end
	local kind = mgKind
	mgKind = nil
	mgToken += 1
	mgStatus.Text = ok and "SUCCESS" or "FAILED"
	mgStatus.TextColor3 = ok and Color3.fromRGB(110, 255, 140) or Color3.fromRGB(255, 90, 80)
	remotes.MinigameResult:FireServer(kind, ok, payload)
	task.delay(ok and 0.5 or 0.8, function()
		if not mgKind then
			mgRoot.Visible = false
			minigameOpen = false
			mgClean()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end)
end
mgQuit.MouseButton1Click:Connect(function()
	mgFinish(false)
end)
local function btn(parent, text, size, pos, color, z)
	local b = Instance.new("TextButton")
	b.Size = size b.Position = pos b.Text = text b.Font = Enum.Font.GothamBlack b.TextSize = 20
	b.BackgroundColor3 = color or Color3.fromRGB(50, 54, 62) b.TextColor3 = Color3.new(1, 1, 1) b.AutoButtonColor = true b.ZIndex = z or 43
	b.Parent = parent
	corner(b, 6)
	return b
end
local games = {}
-- 1) SWIPE: drag the card through the reader - not too fast, not too slow
function games.swipe()
	mgTitle.Text = "SWIPE THE KEYCARD"
	mgHint.Text = "Drag the card all the way to the right in one smooth motion. Not too fast, not too slow."
	local track = frame(mgArea, { Size = UDim2.new(1, 0, 0, 70), Position = UDim2.new(0, 0, 0.35, 0), BackgroundColor3 = Color3.fromRGB(30, 32, 38), ZIndex = 42 })
	corner(track, 8)
	local card = btn(track, "CARD", UDim2.new(0, 90, 1, -10), UDim2.new(0, 5, 0, 5), Color3.fromRGB(60, 150, 255))
	local dragging, startT, startX = false, 0, 0
	table.insert(mgConns, card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, startT, startX = true, os.clock(), input.Position.X
		end
	end))
	table.insert(mgConns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local maxX = track.AbsoluteSize.X - 100
			local x = math.clamp(input.Position.X - startX, 0, maxX)
			card.Position = UDim2.new(0, 5 + x, 0, 5)
			if x >= maxX - 2 then
				dragging = false
				local t = os.clock() - startT
				if t < 0.3 then
					mgStatus.Text = "TOO FAST - try again"
					card.Position = UDim2.new(0, 5, 0, 5)
				elseif t > 1.4 then
					mgStatus.Text = "TOO SLOW - try again"
					card.Position = UDim2.new(0, 5, 0, 5)
				else
					mgFinish(true)
				end
			end
		end
	end))
	table.insert(mgConns, UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			card.Position = UDim2.new(0, 5, 0, 5)
			mgStatus.Text = "Keep the card moving all the way!"
		end
	end))
end
-- 2) KEYPAD
function games.keypad(data)
	mgTitle.Text = "SAFE KEYPAD"
	mgHint.Text = "Enter the 4-digit code. (Marsh wrote it down somewhere...)"
	local entry = ""
	local disp = label(mgArea, { Size = UDim2.new(0, 220, 0, 44), Position = UDim2.new(0.5, -110, 0, 0), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(10, 30, 16), Font = Enum.Font.Code, TextSize = 34, TextColor3 = Color3.fromRGB(90, 255, 140), Text = "----", ZIndex = 42 })
	local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK" }
	for i, k in keys do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local b = btn(mgArea, k, UDim2.new(0, 70, 0, 40), UDim2.new(0.5, -115 + col * 80, 0, 52 + row * 46), k == "OK" and Color3.fromRGB(40, 120, 60) or (k == "C" and Color3.fromRGB(120, 50, 40) or nil))
		b.MouseButton1Click:Connect(function()
			if k == "C" then
				entry = ""
			elseif k == "OK" then
				if #entry == (data.length or 4) then
					mgFinish(true, entry)
				end
				return
			elseif #entry < (data.length or 4) then
				entry ..= k
			end
			disp.Text = entry .. string.rep("-", (data.length or 4) - #entry)
		end)
	end
end
-- 3) WIRES: connect each colour to its match
function games.wires(data)
	mgTitle.Text = "CELL LOCK - REWIRE"
	mgHint.Text = "Click a wire on the left, then the socket of the SAME colour on the right. One mistake resets the lock."
	local colors = { Color3.fromRGB(230, 60, 50), Color3.fromRGB(60, 150, 255), Color3.fromRGB(250, 210, 60), Color3.fromRGB(80, 220, 110) }
	local n = data.count or 4
	local order = {}
	for i = 1, n do order[i] = i end
	for i = n, 2, -1 do local j = math.random(i) order[i], order[j] = order[j], order[i] end
	local picked, done = nil, 0
	for i = 1, n do
		local l = btn(mgArea, "", UDim2.new(0, 70, 0, 34), UDim2.new(0, 10, 0, (i - 1) * 50), colors[i])
		local r = btn(mgArea, "", UDim2.new(0, 70, 0, 34), UDim2.new(1, -80, 0, (order[i] - 1) * 50), colors[i])
		l.MouseButton1Click:Connect(function()
			if l:GetAttribute("Done") then return end
			picked = i
			mgStatus.Text = "Now pick the matching socket..."
		end)
		r.MouseButton1Click:Connect(function()
			if not picked or r:GetAttribute("Done") then return end
			if picked == i then
				l:SetAttribute("Done", true) r:SetAttribute("Done", true)
				local wire = frame(mgArea, { BackgroundColor3 = colors[i], ZIndex = 42, AnchorPoint = Vector2.new(0.5, 0.5) })
				local a = Vector2.new(80, (i - 1) * 50 + 17)
				local b2 = Vector2.new(mgArea.AbsoluteSize.X - 80, (order[i] - 1) * 50 + 17)
				local mid = (a + b2) / 2
				wire.Position = UDim2.fromOffset(mid.X, mid.Y)
				wire.Size = UDim2.fromOffset((b2 - a).Magnitude, 6)
				wire.Rotation = math.deg(math.atan2(b2.Y - a.Y, b2.X - a.X))
				done += 1
				picked = nil
				if done >= n then
					mgFinish(true)
				end
			else
				mgFinish(false)
			end
		end)
	end
end
-- 4) LOCKPICK: stop the pick in the green zone for every pin
function games.lockpick(data)
	mgTitle.Text = "PICK THE LOCK"
	mgHint.Text = "Click (or press SPACE) when the pick is inside the green zone. 3 pins - 2 mistakes allowed."
	local pins, misses, t0 = 0, 0, os.clock()
	local bar = frame(mgArea, { Size = UDim2.new(1, -40, 0, 40), Position = UDim2.new(0, 20, 0.4, 0), BackgroundColor3 = Color3.fromRGB(40, 40, 46), ZIndex = 42 })
	local zone = frame(bar, { Size = UDim2.new(0.16, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(60, 200, 90), ZIndex = 43 })
	local pick = frame(bar, { Size = UDim2.new(0, 6, 1, 10), Position = UDim2.new(0, 0, 0, -5), BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 44 })
	local pinsLabel = label(mgArea, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0.7, 0), TextSize = 20, Text = "PINS: 0/3", ZIndex = 42 })
	local function newZone()
		zone.Position = UDim2.new(math.random() * 0.8, 0, 0, 0)
		zone.Size = UDim2.new(0.16 - pins * 0.03, 0, 1, 0)
	end
	newZone()
	local x = 0
	table.insert(mgConns, RunService.Heartbeat:Connect(function()
		local speed = 0.7 + pins * 0.35
		x = (math.sin((os.clock() - t0) * speed * 3) + 1) / 2
		pick.Position = UDim2.new(x, -3, 0, -5)
	end))
	local function press()
		local zx, zw = zone.Position.X.Scale, zone.Size.X.Scale
		if x >= zx and x <= zx + zw then
			pins += 1
			pinsLabel.Text = ("PINS: %d/%d"):format(pins, data.pins or 3)
			if pins >= (data.pins or 3) then
				mgFinish(true)
				return
			end
			newZone()
		else
			misses += 1
			mgStatus.Text = ("Slipped! (%d/2)"):format(misses)
			if misses >= 3 then
				mgFinish(false)
			end
		end
	end
	local clicker = btn(mgArea, "", UDim2.fromScale(1, 1), UDim2.new(), Color3.new(), 41)
	clicker.BackgroundTransparency = 1
	clicker.MouseButton1Click:Connect(press)
	table.insert(mgConns, UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space then
			press()
		end
	end))
end
-- 5) HACK: find the matching code before the timer runs out
function games.hack(data)
	mgTitle.Text = "BYPASS THE FIREWALL"
	mgHint.Text = "Find the code shown at the top in the grid before time runs out. 3 rounds."
	local chars = "ABCDEF0123456789"
	local function code()
		local s = ""
		for _ = 1, 4 do
			local i = math.random(#chars)
			s ..= chars:sub(i, i)
		end
		return s
	end
	local roundN = 0
	local target = label(mgArea, { Size = UDim2.new(1, 0, 0, 34), Font = Enum.Font.Code, TextSize = 30, TextColor3 = Color3.fromRGB(90, 255, 140), ZIndex = 42 })
	local timerBar = frame(mgArea, { Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0, 38), BackgroundColor3 = Color3.fromRGB(255, 200, 70), ZIndex = 42 })
	local grid = frame(mgArea, { Size = UDim2.new(1, 0, 1, -54), Position = UDim2.new(0, 0, 0, 52), BackgroundTransparency = 1, ZIndex = 42 })
	local deadline = 0
	local token = mgToken
	local function nextRound()
		roundN += 1
		if roundN > (data.rounds or 3) then
			mgFinish(true)
			return
		end
		grid:ClearAllChildren()
		local t = code()
		target.Text = ("ROUND %d/%d   FIND: %s"):format(roundN, data.rounds or 3, t)
		local slot = math.random(16)
		for i = 1, 16 do
			local c = i == slot and t or code()
			if c == t and i ~= slot then c = code() end
			local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
			local b = btn(grid, c, UDim2.new(0.24, 0, 0.23, 0), UDim2.new(col * 0.253, 0, row * 0.25, 0), Color3.fromRGB(20, 40, 26))
			b.Font = Enum.Font.Code
			b.TextColor3 = Color3.fromRGB(90, 255, 140)
			b.MouseButton1Click:Connect(function()
				if c == t then
					nextRound()
				else
					mgFinish(false)
				end
			end)
		end
		deadline = os.clock() + 7 - roundN
	end
	nextRound()
	table.insert(mgConns, RunService.Heartbeat:Connect(function()
		if mgToken ~= token or not mgKind then
			return
		end
		local left = deadline - os.clock()
		timerBar.Size = UDim2.new(math.clamp(left / 6, 0, 1), 0, 0, 6)
		if left <= 0 then
			mgFinish(false)
		end
	end))
end
-- 6) SIMON: repeat the light sequence
function games.simon(data)
	mgTitle.Text = "TRANSMITTER BOOT SEQUENCE"
	mgHint.Text = "Watch the lights, then press them in the same order."
	local colors = { Color3.fromRGB(230, 60, 50), Color3.fromRGB(60, 150, 255), Color3.fromRGB(250, 210, 60), Color3.fromRGB(80, 220, 110) }
	local pads = {}
	for i = 1, 4 do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		local b = btn(mgArea, "", UDim2.new(0.46, 0, 0.44, 0), UDim2.new(col * 0.52, 0, row * 0.5, 0), colors[i]:Lerp(Color3.new(), 0.6))
		pads[i] = b
	end
	local seq = {}
	for i = 1, data.length or 5 do seq[i] = math.random(4) end
	local input, ready = 0, false
	local token = mgToken
	task.spawn(function()
		task.wait(0.6)
		for _, s in seq do
			if mgToken ~= token then return end
			pads[s].BackgroundColor3 = colors[s]
			sound("", 0.3, 0.8 + s * 0.15)
			task.wait(0.45)
			pads[s].BackgroundColor3 = colors[s]:Lerp(Color3.new(), 0.6)
			task.wait(0.2)
		end
		ready = true
		mgStatus.Text = "Your turn!"
	end)
	for i, b in pads do
		b.MouseButton1Click:Connect(function()
			if not ready or not mgKind then return end
			b.BackgroundColor3 = colors[i]
			task.delay(0.15, function() b.BackgroundColor3 = colors[i]:Lerp(Color3.new(), 0.6) end)
			input += 1
			if seq[input] ~= i then
				mgFinish(false)
			elseif input >= #seq then
				mgFinish(true)
			end
		end)
	end
end
-- 7) DISH: find the strongest signal and hold it
function games.dish()
	mgTitle.Text = "ALIGN THE SATELLITE DISH"
	mgHint.Text = "Use the arrows (or W A S D) to aim. Keep the signal above 90% for 2 seconds."
	local az, el = math.random(), math.random()
	local tAz, tEl = math.random() * 0.8 + 0.1, math.random() * 0.8 + 0.1
	local meter = frame(mgArea, { Size = UDim2.new(1, -40, 0, 30), Position = UDim2.new(0, 20, 0, 0), BackgroundColor3 = Color3.fromRGB(30, 32, 38), ZIndex = 42 })
	local fill = frame(meter, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(90, 220, 255), ZIndex = 43 })
	local pct = label(meter, { Size = UDim2.fromScale(1, 1), TextSize = 18, Font = Enum.Font.GothamBlack, ZIndex = 44 })
	local scope = frame(mgArea, { Size = UDim2.new(0, 150, 0, 150), Position = UDim2.new(0.5, -75, 0, 44), BackgroundColor3 = Color3.fromRGB(10, 20, 24), ZIndex = 42 })
	corner(scope, 75)
	local dot = frame(scope, { Size = UDim2.new(0, 12, 0, 12), BackgroundColor3 = Color3.fromRGB(255, 200, 70), ZIndex = 43, AnchorPoint = Vector2.new(0.5, 0.5) })
	corner(dot, 6)
	local held = { up = false, down = false, left = false, right = false }
	local function arrow(t, pos, key)
		local b = btn(mgArea, t, UDim2.new(0, 46, 0, 40), pos)
		b.MouseButton1Down:Connect(function() held[key] = true end)
		b.MouseButton1Up:Connect(function() held[key] = false end)
		b.MouseLeave:Connect(function() held[key] = false end)
	end
	arrow("^", UDim2.new(0.5, -23, 0, 200), "up") arrow("v", UDim2.new(0.5, -23, 0, 244), "down")
	arrow("<", UDim2.new(0.5, -75, 0, 222), "left") arrow(">", UDim2.new(0.5, 29, 0, 222), "right")
	local goodFor = 0
	local token = mgToken
	table.insert(mgConns, RunService.Heartbeat:Connect(function(dt)
		if mgToken ~= token or not mgKind then return end
		local k = UserInputService
		if held.left or k:IsKeyDown(Enum.KeyCode.A) or k:IsKeyDown(Enum.KeyCode.Left) then az -= dt * 0.25 end
		if held.right or k:IsKeyDown(Enum.KeyCode.D) or k:IsKeyDown(Enum.KeyCode.Right) then az += dt * 0.25 end
		if held.up or k:IsKeyDown(Enum.KeyCode.W) or k:IsKeyDown(Enum.KeyCode.Up) then el -= dt * 0.25 end
		if held.down or k:IsKeyDown(Enum.KeyCode.S) or k:IsKeyDown(Enum.KeyCode.Down) then el += dt * 0.25 end
		az, el = math.clamp(az, 0, 1), math.clamp(el, 0, 1)
		-- a little wind drift
		az += math.sin(os.clock() * 1.7) * dt * 0.02
		local d = math.sqrt((az - tAz) ^ 2 + (el - tEl) ^ 2)
		local signal = math.clamp(1 - d * 2.2, 0, 1)
		fill.Size = UDim2.fromScale(signal, 1)
		pct.Text = ("SIGNAL %d%%"):format(signal * 100)
		dot.Position = UDim2.fromScale(az, el)
		fill.BackgroundColor3 = signal > 0.9 and Color3.fromRGB(110, 255, 140) or Color3.fromRGB(90, 220, 255)
		if signal > 0.9 then
			goodFor += dt
			if goodFor >= 2 then
				mgFinish(true)
			end
		else
			goodFor = 0
		end
	end))
end
-- 8) GENERATOR: pull the cord in rhythm
function games.generator(data)
	mgTitle.Text = "RESTART THE GENERATOR"
	mgHint.Text = "Click (or press SPACE) when the shrinking circle touches the ring. 4 good pulls - 2 misses allowed."
	local ring = frame(mgArea, { Size = UDim2.new(0, 90, 0, 90), Position = UDim2.new(0.5, -45, 0.45, -45), BackgroundTransparency = 1, ZIndex = 42 })
	local rs = Instance.new("UIStroke") rs.Thickness = 4 rs.Color = Color3.fromRGB(110, 255, 140) rs.Parent = ring
	corner(ring, 45)
	local circle = frame(mgArea, { Size = UDim2.new(0, 220, 0, 220), Position = UDim2.new(0.5, 0, 0.45, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 43 })
	local cs = Instance.new("UIStroke") cs.Thickness = 3 cs.Color = Color3.fromRGB(255, 200, 70) cs.Parent = circle
	corner(circle, 200)
	local good, misses, size = 0, 0, 220
	local count = label(mgArea, { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 1, -26), TextSize = 20, Text = "PULLS: 0/4", ZIndex = 42 })
	local token = mgToken
	table.insert(mgConns, RunService.Heartbeat:Connect(function(dt)
		if mgToken ~= token or not mgKind then return end
		size -= dt * (110 + good * 30)
		if size < 40 then
			size = 220
			misses += 1
			mgStatus.Text = ("Too late! (%d/2)"):format(misses)
			if misses >= 3 then mgFinish(false) end
		end
		circle.Size = UDim2.fromOffset(size, size)
	end))
	local function pull()
		if math.abs(size - 90) < 18 then
			good += 1
			count.Text = ("PULLS: %d/%d"):format(good, data.pulls or 4)
			mgStatus.Text = good < (data.pulls or 4) and "Vrrrm..." or ""
			size = 220
			if good >= (data.pulls or 4) then mgFinish(true) end
		else
			misses += 1
			size = 220
			mgStatus.Text = ("Bad pull! (%d/2)"):format(misses)
			if misses >= 3 then mgFinish(false) end
		end
	end
	local clicker = btn(mgArea, "", UDim2.fromScale(1, 1), UDim2.new(), Color3.new(), 41)
	clicker.BackgroundTransparency = 1
	clicker.MouseButton1Click:Connect(pull)
	table.insert(mgConns, UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space then pull() end
	end))
end
-- 9) BREATH: something is right outside your hiding spot
function games.breath(data)
	mgTitle.Text = "HOLD YOUR BREATH"
	mgHint.Text = "Something is right outside. HOLD the button (or SPACE) to keep the marker inside the zone. Don't let it slip!"
	mgQuit.Visible = false
	local bar = frame(mgArea, { Size = UDim2.new(0, 60, 1, -20), Position = UDim2.new(0.5, -30, 0, 0), BackgroundColor3 = Color3.fromRGB(30, 30, 36), ZIndex = 42 })
	local zone = frame(bar, { Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.new(0, 0, 0.35, 0), BackgroundColor3 = Color3.fromRGB(60, 200, 90), ZIndex = 43 })
	local mark = frame(bar, { Size = UDim2.new(1, 10, 0, 6), Position = UDim2.new(0, -5, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 44 })
	local hold = btn(mgArea, "HOLD", UDim2.new(0, 120, 0, 50), UDim2.new(0.5, 40, 0.5, -25), Color3.fromRGB(60, 90, 140))
	local holding = false
	hold.MouseButton1Down:Connect(function() holding = true end)
	hold.MouseButton1Up:Connect(function() holding = false end)
	local y, vel, outside, t0 = 0.5, 0, 0, os.clock()
	local token = mgToken
	table.insert(mgConns, RunService.Heartbeat:Connect(function(dt)
		if mgToken ~= token or not mgKind then return end
		local up = holding or UserInputService:IsKeyDown(Enum.KeyCode.Space)
		vel += (up and -1.6 or 1.3) * dt
		vel *= 0.96
		y = math.clamp(y + vel * dt, 0, 1)
		zone.Position = UDim2.new(0, 0, 0.35 + math.sin((os.clock() - t0) * 1.3) * 0.25, 0)
		mark.Position = UDim2.new(0, -5, y, -3)
		local zy = zone.Position.Y.Scale
		if y < zy or y > zy + 0.3 then
			outside += dt
			mark.BackgroundColor3 = Color3.fromRGB(255, 90, 80)
		else
			mark.BackgroundColor3 = Color3.new(1, 1, 1)
		end
		if outside > 1.4 then
			mgFinish(false)
		elseif os.clock() - t0 > (data.time or 6) then
			mgFinish(true)
		end
	end))
end
remotes:WaitForChild("Minigame").OnClientEvent:Connect(function(kind, data)
	if kind == "cancel" then
		if mgKind then
			mgKind = nil
			mgToken += 1
			mgRoot.Visible = false
			minigameOpen = false
			mgClean()
		end
		return
	end
	if not games[kind] or cutscenePlaying then
		remotes.MinigameResult:FireServer(kind, false)
		return
	end
	mgClean()
	mgToken += 1
	mgKind = kind
	mgStatus.Text = ""
	mgQuit.Visible = true
	mgRoot.Visible = true
	minigameOpen = true
	paper.Visible = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	games[kind](data or {})
end)

-- DIFFICULTY PICKER ---------------------------------------------------------------------
local introPlaying = false
local picker = frame(overlay, { Size = UDim2.new(0, 860, 0, 300), Position = UDim2.new(0.5, -430, 0.5, -150), BackgroundColor3 = Color3.fromRGB(14, 12, 12), BackgroundTransparency = 0.05, Visible = false, ZIndex = 20 })
corner(picker, 10)
local ps = Instance.new("UIStroke") ps.Color = Color3.fromRGB(200, 120, 60) ps.Thickness = 2 ps.Parent = picker
label(picker, { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.new(0, 0, 0, 8), Font = Enum.Font.Creepster, TextScaled = true, TextColor3 = Color3.fromRGB(255, 170, 90), Text = "WILDCREST HQ - CHOOSE YOUR NIGHT", ZIndex = 21 })
local pickTimer = label(picker, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -32), TextSize = 16, ZIndex = 21 })
for i, name in Config.DifficultyOrder do
	local d = Config.Difficulties[name]
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 196, 0, 190) b.Position = UDim2.new(0, 18 + (i - 1) * 206, 0, 70) b.BackgroundColor3 = Color3.fromRGB(28, 26, 28) b.Text = "" b.ZIndex = 21 b.Parent = picker
	corner(b, 8)
	label(b, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 8), Font = Enum.Font.GothamBlack, TextSize = 26, TextColor3 = d.Color, Text = name:upper(), ZIndex = 22 })
	label(b, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 48), TextSize = 18, TextColor3 = Color3.fromRGB(255, 90, 90), Text = string.rep("<3 ", d.Lives), ZIndex = 22 })
	label(b, { Size = UDim2.new(1, -16, 0, 100), Position = UDim2.new(0, 8, 0, 78), TextWrapped = true, TextSize = 18, Text = d.Blurb, ZIndex = 22 })
	b.MouseButton1Click:Connect(function()
		remotes.ChooseDifficulty:FireServer(name)
	end)
end
RunService.Heartbeat:Connect(function()
	local choosing = RS:GetAttribute("DifficultyChoosing") == true
	picker.Visible = choosing and not introPlaying and player:GetAttribute("InGame") == true
	if picker.Visible then
		pickTimer.Text = ("Anyone can choose. Defaults to NORMAL in %ds"):format(math.max(0, math.ceil((RS:GetAttribute("DifficultyDeadline") or 0) - workspace:GetServerTimeNow())))
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

-- CUTSCENE HELPERS ----------------------------------------------------------------------
local letterTop = frame(overlay, { Size = UDim2.new(1, 0, 0.12, 0), BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 25 })
local letterBot = frame(overlay, { Size = UDim2.new(1, 0, 0.16, 0), Position = UDim2.fromScale(0, 0.84), BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 25 })
local sub = label(overlay, { Size = UDim2.new(0.9, 0, 0.1, 0), Position = UDim2.fromScale(0.05, 0.86), TextWrapped = true, TextSize = 24, Text = "", ZIndex = 26 })
local black = frame(overlay, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 27 })
local title = label(overlay, { Size = UDim2.new(1, 0, 0, 90), Position = UDim2.fromScale(0, 0.38), Font = Enum.Font.Creepster, TextScaled = true, TextColor3 = Color3.fromRGB(255, 80, 60), Text = "", ZIndex = 28 })
local titleSub = label(overlay, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromScale(0, 0.52), TextSize = 22, Text = "", ZIndex = 28 })
local function beginCut()
	cutscenePlaying = true
	gui.Enabled = false
	paper.Visible = false
	letterTop.Visible, letterBot.Visible = true, true
	camera.CameraType = Enum.CameraType.Scriptable
end
local function endCut()
	letterTop.Visible, letterBot.Visible = false, false
	sub.Text = ""
	title.Text, titleSub.Text = "", ""
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	gui.Enabled = true
	cutscenePlaying = false
	TweenService:Create(black, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
end
local function fade(to, t)
	TweenService:Create(black, TweenInfo.new(t or 0.5), { BackgroundTransparency = to }):Play()
end
-- run a timeline: shots = { {t0, t1, function(k) return camCFrame end}, ... }, lines = { {t, text, who}, ... }
local function timeline(duration, shots, lines, skippable, onTick)
	local t0 = os.clock()
	local skipped = false
	local lineList = table.clone(lines or {})
	local skip
	if skippable then
		skip = Instance.new("TextButton")
		skip.Size = UDim2.new(0, 120, 0, 34) skip.Position = UDim2.new(1, -140, 0, 20) skip.Text = "Skip >>" skip.Font = Enum.Font.GothamBold skip.TextSize = 16
		skip.BackgroundColor3 = Color3.fromRGB(30, 30, 34) skip.TextColor3 = Color3.new(1, 1, 1) skip.ZIndex = 30 skip.Parent = overlay
		corner(skip, 6)
		skip.MouseButton1Click:Connect(function()
			t0 = -1e9
			skipped = true
		end)
	end
	while os.clock() - t0 < duration do
		local t = os.clock() - t0
		for i = #lineList, 1, -1 do
			if t >= lineList[i][1] then
				local l = lineList[i]
				if l[3] then
					sub.Text = l[3] .. ": " .. l[2]
				else
					sub.Text = l[2]
				end
				table.remove(lineList, i)
			end
		end
		if onTick then
			local ok, err = pcall(onTick, t)
			if not ok then
				warn("cutscene tick: " .. tostring(err))
				onTick = nil
			end
		end
		for _, s in shots do
			if t >= s[1] and t < s[2] then
				camera.CFrame = s[3]((t - s[1]) / (s[2] - s[1]))
			end
		end
		RunService.Heartbeat:Wait() -- (keeps going even when the window isn't drawing)
	end
	if skip then
		skip:Destroy()
	end
	return skipped
end
local function lerpCF(a, b, k)
	k = k * k * (3 - 2 * k)
	return a:Lerp(b, k)
end

local playSneak, setBlackout -- (defined below)
-- CUTSCENE ACTORS (local-only puppets that walk, point and laugh) -----------------------
local ANIM = { point = 507770453, laugh = 507770818, pwalk = 507777826, pidle = 507766388, pclimb = 507765644 }
local actors = {}
local function makeActor(src, feetPos, lookAt)
	if not src then
		return nil
	end
	local wasArch = src.Archivable
	src.Archivable = true
	local ok, a = pcall(function()
		return src:Clone()
	end)
	src.Archivable = wasArch
	if not ok or not a then
		return nil
	end
	local hum = a:FindFirstChildOfClass("Humanoid")
	local root = a:FindFirstChild("HumanoidRootPart") or a.PrimaryPart
	if not hum or not root then
		a:Destroy()
		return nil
	end
	a.PrimaryPart = root
	for _, d in a:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("ForceField") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
			d.Anchored = d == root
			d.LocalTransparencyModifier = 0
		end
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	local hip = a:GetAttribute("HipHeight") or (hum.HipHeight + root.Size.Y / 2)
	a.Name = "CutsceneActor"
	local act = { model = a, root = root, hip = hip, animator = animator, tracks = {} }
	local look = lookAt and Vector3.new(lookAt.X, feetPos.Y, lookAt.Z)
	local cf = (look and (look - feetPos).Magnitude > 0.05) and CFrame.lookAt(feetPos, look) or CFrame.new(feetPos)
	a:PivotTo(cf + Vector3.new(0, hip, 0))
	a.Parent = workspace
	table.insert(actors, act)
	return act
end
local function loadTrack(act, id)
	if act.model:GetAttribute("BoneRig") then
		return nil -- the crawler is animated bone by bone instead
	end
	if act.tracks[id] then
		return act.tracks[id]
	end
	local an = Instance.new("Animation")
	an.AnimationId = "rbxassetid://" .. tostring(id)
	local ok, tr = pcall(function()
		return act.animator:LoadAnimation(an)
	end)
	if ok and tr then
		act.tracks[id] = tr
		return tr
	end
end
local function actorBase(act, id, speed) -- looping walk/idle
	if not act or not id then
		return
	end
	local t = loadTrack(act, id)
	if not t then
		return
	end
	if act.base and act.base ~= t then
		act.base:Stop(0.3)
	end
	act.base = t
	t.Priority = Enum.AnimationPriority.Movement
	t.Looped = true
	if not t.IsPlaying then
		t:Play(0.3)
	end
	t:AdjustSpeed(speed or 1)
end
local function actorGesture(act, id, looped, speed) -- point / laugh on top
	if not act or not id then
		return
	end
	local t = loadTrack(act, id)
	if not t then
		return
	end
	t.Priority = Enum.AnimationPriority.Action2
	t.Looped = looped and true or false
	t:Play(0.2)
	t:AdjustSpeed(speed or 1)
	return t
end
local function actorPlace(act, feetPos, lookAt)
	if not act then
		return
	end
	local cf
	if lookAt and (Vector3.new(lookAt.X, feetPos.Y, lookAt.Z) - feetPos).Magnitude > 0.05 then
		cf = CFrame.lookAt(feetPos, Vector3.new(lookAt.X, feetPos.Y, lookAt.Z))
	else
		cf = CFrame.new(feetPos) * act.root.CFrame.Rotation
	end
	act.model:PivotTo(cf + Vector3.new(0, act.hip, 0))
	act.feet = feetPos
end
local function actorWalk(act, from, to, k)
	k = math.clamp(k, 0, 1)
	local d = to - from
	local ahead = d.Magnitude > 0.05 and (to + d.Unit * 5) or nil
	actorPlace(act, from:Lerp(to, k), ahead)
end
local function actorHead(act, fallback)
	return act and (act.root.Position + Vector3.new(0, 1.6, 0)) or fallback
end
local function clearActors()
	for _, a in actors do
		for _, t in a.tracks do
			pcall(function()
				t:Stop(0)
			end)
		end
		a.model:Destroy()
	end
	table.clear(actors)
end
local function hideReal(kind, hidden)
	local folder = workspace:FindFirstChild("Monsters")
	if not folder then
		return
	end
	for _, m in folder:GetChildren() do
		if m.Name == kind then
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = hidden and 1 or 0
				end
			end
		end
	end
end
-- find open floor around a spot: returns the most open direction (to walk in from) and one roughly opposite (for the camera)
local function openDirs(feet, maxD)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = {}
	for _, n in { "Monsters", "Items" } do
		if workspace:FindFirstChild(n) then
			table.insert(ex, workspace[n])
		end
	end
	if player.Character then
		table.insert(ex, player.Character)
	end
	for _, a in actors do
		table.insert(ex, a.model)
	end
	params.FilterDescendantsInstances = ex
	local res = {}
	for i = 0, 15 do
		local ang = i * math.pi / 8
		local dir = Vector3.new(math.sin(ang), 0, math.cos(ang))
		local d = maxD
		for _, h in { 1.5, 3.5, 5.5 } do
			local hit = workspace:Raycast(feet + Vector3.new(0, h, 0), dir * maxD, params)
			if hit then
				d = math.min(d, hit.Distance)
			end
		end
		table.insert(res, { dir = dir, d = d })
	end
	table.sort(res, function(a, b)
		return a.d > b.d
	end)
	local walk, cam = res[1], nil
	for _, r in res do
		if r.dir:Dot(walk.dir) < -0.3 and r.d >= 4 then
			cam = r
			break
		end
	end
	return walk, cam or res[2]
end

-- INTRO ---------------------------------------------------------------------------------
local H = 14
local F12, F10 = 11 * H, 9 * H
local function playIntro()
	introPlaying = true
	beginCut()
	black.BackgroundTransparency = 0
	fade(1, 1.5)
	local tower = Vector3.new(0, 120, 0)
	-- you, asleep in bed
	local me = makeActor(player.Character, Vector3.new(-30, F12, -24))
	if me then
		actorBase(me, ANIM.pidle, 1)
		me.model:PivotTo(CFrame.new(-36, F12 + 2.9, -24) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(-90), 0, 0))
	end
	-- the phone on the nightstand
	local phone = Instance.new("Part")
	phone.Anchored, phone.CanCollide, phone.CanQuery = true, false, false
	phone.Size = Vector3.new(0.5, 0.06, 0.9)
	phone.CFrame = CFrame.new(-38.2, F12 + 2.25, -19.4)
	phone.Color = Color3.fromRGB(20, 20, 24)
	phone.Material = Enum.Material.SmoothPlastic
	phone.Parent = workspace
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(150, 200, 255)
	glow.Range = 8
	glow.Brightness = 0
	glow.Parent = phone
	-- Wildcrest's vans roll up outside (they start further down the street)
	local raid = workspace:FindFirstChild("City") and workspace.City:FindFirstChild("Raid")
	local vans = {}
	if raid then
		for i, v in raid:GetChildren() do
			if v:IsA("Model") then
				local home = v:GetPivot()
				local from = home * CFrame.new(0, 0, 90 + i * 25) -- behind them (they drive forward)
				table.insert(vans, { m = v, home = home, from = from, delay = i * 0.6 })
				v:PivotTo(from)
			end
		end
	end
	-- a squad of SWAT walking into the lobby
	local squad = {}
	for i = 1, 4 do
		local a = makeActor(views:FindFirstChild("Guard"), Vector3.new(-6 + i * 3, 0, -48), Vector3.new(0, 0, -30))
		if a then
			actorBase(a, Config.Monsters.Guard.Anim.walk, 0.6)
			table.insert(squad, { a = a, from = Vector3.new(-6 + i * 3, 0, -48 - i * 2), to = Vector3.new(-3 + i * 1.6, 0, -24 + i) })
		end
	end
	local buzzed = false
	local lines = {
		{ 0.5, "Two weeks since you tried to expose Wildcrest. Two weeks of hiding in your apartment." },
		{ 5, "No job. No proof. Just the feeling that someone is always watching." },
		{ 9.5, "Tonight the city is quiet. Almost." },
		{ 12.5, "Three black vans. No sirens. No plates." },
		{ 16, "They don't knock on anyone's door. They walk straight to the elevator." },
		{ 21, "Twelve floors up, you're asleep." },
		{ 26.5, "*BZZZT* - your phone lights up. Unknown number." },
		{ 29.5, "THEY FOUND YOU. WILDCREST IS IN THE BUILDING. GET OUT NOW.", "UNKNOWN NUMBER" },
		{ 34, "...Who sent that?", "YOU" },
		{ 36.5, "" },
	}
	local shots = {
		{ 0, 9, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-160, 95, -190), tower), CFrame.lookAt(Vector3.new(-90, 70, -130), tower), k) end },
		-- the vans arrive
		{ 9, 15, function(k) return lerpCF(CFrame.lookAt(Vector3.new(40, 5, -74), Vector3.new(0, 3, -50)), CFrame.lookAt(Vector3.new(30, 4, -70), Vector3.new(-5, 3, -50)), k) end },
		-- SWAT walk into the lobby
		{ 15, 20, function(k) return lerpCF(CFrame.lookAt(Vector3.new(12, 7, -20), Vector3.new(0, 4, -36)), CFrame.lookAt(Vector3.new(9, 6.5, -16), Vector3.new(0, 4, -28)), k) end },
		-- up the facade to your window
		{ 20, 26, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-22, 70, -75), Vector3.new(-21, 150, -32)), CFrame.lookAt(Vector3.new(-21.5, F12 + 6, -44), Vector3.new(-21.5, F12 + 5, -30)), k) end },
		{ 26, 34, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-29, F12 + 7, -28.5), Vector3.new(-36, F12 + 2.5, -22)), CFrame.lookAt(Vector3.new(-31, F12 + 6, -26.5), Vector3.new(-37.5, F12 + 2.4, -20)), k) end },
		{ 34, 40, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-36.6, F12 + 4, -21.5), Vector3.new(-38.2, F12 + 2.3, -19.4)), CFrame.lookAt(Vector3.new(-37.2, F12 + 3.4, -20.6), Vector3.new(-38.2, F12 + 2.3, -19.4)), k) end },
	}
	task.delay(36.5, function()
		if introPlaying then
			title.Text = "CHAPTER 4: LAST STOP"
			titleSub.Text = "they know where you live"
		end
	end)
	timeline(Config.IntroTime, shots, lines, true, function(t)
		for _, v in vans do
			local k = math.clamp((t - 9.2 - v.delay) / 4.5, 0, 1)
			k = 1 - (1 - k) * (1 - k) -- ease out: brake to a stop
			v.m:PivotTo(v.from:Lerp(v.home, k))
		end
		for _, sq in squad do
			local k = math.clamp((t - 13.5) / 6, 0, 1)
			actorPlace(sq.a, sq.from:Lerp(sq.to, k), sq.to + (sq.to - sq.from).Unit * 4)
		end
		if t >= 26.5 then
			glow.Brightness = (math.floor(t * 4) % 2 == 0) and 2 or 0.6
			if not buzzed then
				buzzed = true
				sound(Config.Sounds.Heartbeat, 0.6, 2.5)
			end
		end
	end)
	for _, v in vans do
		v.m:PivotTo(v.home)
	end
	phone:Destroy()
	clearActors()
	title.Text, titleSub.Text = "", ""
	introPlaying = false
	endCut()
	notice("Wildcrest found you. Get out of the building!", Color3.fromRGB(255, 210, 120), 6)
end
task.spawn(function()
	while player:GetAttribute("InGame") ~= true do
		player:GetAttributeChangedSignal("InGame"):Wait()
	end
	task.wait(0.5)
	local left = (RS:GetAttribute("IntroUntil") or 0) - workspace:GetServerTimeNow()
	if RS:GetAttribute("DifficultyChoosing") == true and left > 5 then
		local ok, err = pcall(playIntro)
		if not ok then
			warn("Intro error: " .. tostring(err))
			clearActors()
			introPlaying = false
			endCut()
		end
	end
end)

-- STORY CUTSCENES -----------------------------------------------------------------------
local cutscenes = {}
local gcfg = Config.Monsters.Guard.Anim
local mcfg = Config.Monsters.Marsh.Anim
local function flashlightOn(act)
	if not act then
		return
	end
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Range = 40
	beam.Angle = 40
	beam.Brightness = 5
	beam.Shadows = true
	beam.Color = Color3.fromRGB(255, 245, 220)
	beam.Parent = act.root
end
function cutscenes.raid(args)
	local door = level.F12.Props:FindFirstChild("FrontDoor")
	local home = door and door.CFrame
	local guards = {}
	for i, p in { Vector3.new(-18.5, F12, 1.2), Vector3.new(-21, F12, 2.4), Vector3.new(-16, F12, 2.4) } do
		local g = makeActor(views:FindFirstChild("Guard"), p, Vector3.new(-18.5, F12, -6))
		actorBase(g, gcfg.idle, 1)
		flashlightOn(g)
		guards[i] = g
	end
	local banged, gestured = {}, false
	timeline(12, {
		{ 0, 4, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-22.5, F12 + 5, -15), Vector3.new(-18.5, F12 + 4, -4)), CFrame.lookAt(Vector3.new(-21.5, F12 + 4.8, -11), Vector3.new(-18.5, F12 + 4, -4)), k) end },
		{ 4, 8, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-8, F12 + 6, 2.6), Vector3.new(-18.5, F12 + 4, 0)), CFrame.lookAt(Vector3.new(-11, F12 + 5.5, 2.2), Vector3.new(-18.5, F12 + 4, 0)), k) end },
		{ 8, 12, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-18, F12 + 5, -12), Vector3.new(-21.5, F12 + 4, -30)), CFrame.lookAt(Vector3.new(-19.5, F12 + 5, -16), Vector3.new(-21.5, F12 + 3, -34)), k) end },
	}, {
		{ 0.3, "*BANG* *BANG* *BANG*" },
		{ 1.8, "WILDCREST SECURITY! OPEN THE DOOR!", "SWAT" },
		{ 4.3, "Target is inside. Bring up the ram.", "SWAT" },
		{ 6.3, "Mr. Marsh wants the ex-employee ALIVE.", "SWAT" },
		{ 8.5, "The front door won't hold for long... The BALCONY. Your neighbor's balcony is right next to yours." },
	}, false, function(t)
		for _, bt in { 0.4, 1.4, 2.4, 3.3 } do
			if t >= bt and not banged[bt] then
				banged[bt] = true
				sound(Config.Sounds.Jumpscare, 0.5, 0.35)
			end
		end
		if door and home then
			local shake = (t < 4 and (t % 1) < 0.25) and 0.12 or 0
			door.CFrame = home * CFrame.new(0, 0, (math.random() - 0.5) * shake * 2)
		end
		if t >= 6.3 and not gestured then
			gestured = true
			actorGesture(guards[1], ANIM.point, false, 1)
		end
	end)
	if door and home then
		door.CFrame = home
	end
end
function cutscenes.swat(args)
	local guards = {}
	local path0, path1 = {}, {}
	for i = 1, 3 do
		path0[i] = Vector3.new(29.5 + (i - 1) * 1.6, F10 - 7, 19 + (i - 1) * 0.0)
		path1[i] = Vector3.new(29.5 + (i - 1) * 1.6, F10 - 3.5, 12 + (i - 1) * 1.5)
		local g = makeActor(views:FindFirstChild("Guard"), path0[i], path1[i])
		actorBase(g, gcfg.run, 0.9)
		flashlightOn(g)
		guards[i] = g
	end
	timeline(8, {
		{ 0, 8, function(k) return lerpCF(CFrame.lookAt(Vector3.new(30.5, F10 + 6, 6), Vector3.new(31, F10 - 6, 17)), CFrame.lookAt(Vector3.new(30.8, F10 + 5, 7), Vector3.new(31, F10 - 4, 15)), k) end },
	}, {
		{ 0.3, "Stairwell B, moving UP! Sweep floors nine through twelve!", "SWAT (radio)" },
		{ 3.3, "They're coming up the stairs. Not this way!", "YOU" },
		{ 5.5, "Floor 10. Get off the stairs - NOW." },
	}, false, function(t)
		for i, g in guards do
			local k = math.clamp((t - (i - 1) * 0.4) / 4.5, 0, 1)
			local p = path0[i]:Lerp(path1[i], k)
			actorPlace(g, p, path1[i] + (path1[i] - path0[i]).Unit * 4)
			if k >= 1 then
				actorBase(g, gcfg.idle, 1)
			end
		end
	end)
end
local function silhouette(feet, lookAt)
	local a = makeActor(views:FindFirstChild("B01"), feet, lookAt)
	if not a then
		return nil
	end
	for _, d in a.model:GetDescendants() do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("Decal") or d:IsA("ShirtGraphic") or d:IsA("SurfaceAppearance") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Color = Color3.new(0, 0, 0)
			d.Material = Enum.Material.SmoothPlastic
			if d:IsA("MeshPart") then
				d.TextureID = ""
			end
		end
	end
	pcall(function()
		a.model:ScaleTo(1.15)
	end)
	return a
end
function cutscenes.arrive(args)
	timeline(9, {
		{ 0, 5, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-45, -8.5, 79), Vector3.new(-45, -10, 100)), CFrame.lookAt(Vector3.new(-48, -8, 86), Vector3.new(-62, -10, 92)), k) end },
		{ 5, 9, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-40, -8.5, 88), Vector3.new(-28, -9, 98.5)), CFrame.lookAt(Vector3.new(-33, -9, 92), Vector3.new(-28, -9, 98.5)), k) end },
	}, {
		{ 0.3, "Old Town station. Closed for years... nobody comes down here any more." },
		{ 4, "The air is cold. Somewhere far below, water is dripping." },
		{ 6.3, "The shutter to the platforms is locked down." },
	})
end
function cutscenes.platform(args)
	local spot = Vector3.new(-69, -34, 238)
	local fig = silhouette(spot, Vector3.new(-69, -34, 130))
	local tubes = {}
	for _, p in level.Parent.Subway.Platform:GetChildren() do
		if p.Name == "Tube" then
			table.insert(tubes, p)
		end
	end
	local gone = false
	timeline(10, {
		{ 0, 3.4, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-45, -25, 137), Vector3.new(-50, -27, 238)), CFrame.lookAt(Vector3.new(-48, -25.5, 145), Vector3.new(-60, -28, 238)), k) end },
		{ 3.4, 7, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-56, -26, 190), spot + Vector3.new(0, 4, 0)), CFrame.lookAt(Vector3.new(-60, -26.5, 210), spot + Vector3.new(0, 4, 0)), k) end },
		{ 7, 10, function(k) return CFrame.lookAt(Vector3.new(-60, -26.5, 210), spot + Vector3.new(0, 3, 0)) end },
	}, {
		{ 0.3, "The platform. Most of the lights are dead." },
		{ 3.5, "...There's someone standing on the tracks." },
		{ 6.1, "" },
		{ 7.3, "...It's gone.", "YOU" },
		{ 8.6, "Was it ever there?" },
	}, false, function(t)
		if t >= 6.1 and t < 7 then
			for _, p in tubes do
				local l = p:FindFirstChildOfClass("PointLight")
				if l then
					l.Enabled = false
				end
			end
			if not gone then
				gone = true
				sound(Config.Sounds.Growl, 0.5, 0.6)
				if fig then
					fig.model:Destroy()
					fig = nil
				end
			end
		elseif t >= 7 then
			for _, p in tubes do
				local l = p:FindFirstChildOfClass("PointLight")
				if l then
					l.Enabled = true
				end
			end
		end
	end)
end
function cutscenes.thing(args)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local pz = root and root.Position.Z or 410
	local x = -69.5
	local spotZ = math.max(262, pz - 30)
	local cam = Vector3.new(x + 1.5, -29.6, pz + 2)
	local fig = makeActor(views:FindFirstChild("Thing"), Vector3.new(x, -34, spotZ), Vector3.new(x, -34, pz))
	local ceilingCF
	if fig then
		ceilingCF = CFrame.new(x, -21.5 - fig.hip, spotZ) * CFrame.Angles(0, 0, math.pi) -- hanging upside down from the roof
		fig.model:PivotTo(ceilingCF)
	end
	local lamp = Instance.new("Part")
	lamp.Anchored, lamp.CanCollide, lamp.CanQuery, lamp.Transparency = true, false, false, 1
	lamp.Size = Vector3.new(0.2, 0.2, 0.2)
	lamp.CFrame = CFrame.lookAt(cam, Vector3.new(x, -27, spotZ))
	lamp.Parent = workspace
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Range = 60
	beam.Angle = 30
	beam.Brightness = 3
	beam.Parent = lamp
	local thud = false
	timeline(9, {
		{ 0, 2, function(k) return CFrame.lookAt(cam, Vector3.new(x, -29, spotZ)) end },
		{ 2, 4, function(k) return lerpCF(CFrame.lookAt(cam, Vector3.new(x, -29, spotZ)), CFrame.lookAt(cam, Vector3.new(x, -22.5, spotZ)), k) end },
		{ 4, 7, function(k) return CFrame.lookAt(cam, Vector3.new(x, -30.5, spotZ + k * 6)) * CFrame.new((math.random() - 0.5) * 0.06, 0, 0) end },
		{ 7, 9, function(k) return CFrame.lookAt(cam, Vector3.new(x, -30.5, pz - 3)) * CFrame.new((math.random() - 0.5) * 0.25, (math.random() - 0.5) * 0.25, 0) end },
	}, {
		{ 0.3, "*Your flashlight flickers.*" },
		{ 2.2, "...Something is on the ceiling." },
		{ 4.1, "*THUD*" },
		{ 5.5, "It's looking at you." },
		{ 7.4, "RUN." },
	}, false, function(t)
		beam.Enabled = not (t < 1.6 and (math.floor(t * 9) % 3 == 0))
		if fig then
			if t < 4 then
				fig.model:PivotTo(ceilingCF)
			elseif t < 6.8 then
				if not thud then
					thud = true
					sound(Config.Sounds.Jumpscare, 0.8, 0.5)
					actorBase(fig, Config.Monsters.Thing.Anim.idle, 1)
				end
				actorPlace(fig, Vector3.new(x, -34, spotZ + (t - 4) * 2.2), Vector3.new(x, -34, pz))
			else
				local k = (t - 6.8) / 1.6
				actorBase(fig, Config.Monsters.Thing.Anim.run, 1.4)
				actorPlace(fig, Vector3.new(x, -34, spotZ + 6 + k * (pz - spotZ - 10)), Vector3.new(x, -34, pz))
			end
		end
	end)
	lamp:Destroy()
end
function cutscenes.collapse(args)
	local rocks = {}
	local spawned = 0
	timeline(8, {
		{ 0, 8, function(k) return CFrame.lookAt(Vector3.new(-56, -27, 860), Vector3.new(-62, -24, 842)) * CFrame.new((math.random() - 0.5) * 0.3 * (1 - k * 0.6), (math.random() - 0.5) * 0.3 * (1 - k * 0.6), 0) end },
	}, {
		{ 0.3, "*RUMBLE*" },
		{ 1.8, "The ceiling is coming down!", "YOU" },
		{ 5, "The way back is gone. Buried." },
	}, false, function(t)
		if t > 0.6 and t < 5 and spawned < 40 and math.random() < 0.6 then
			spawned += 1
			local r = Instance.new("Part")
			r.Size = Vector3.new(1 + math.random() * 3, 1 + math.random() * 2, 1 + math.random() * 3)
			r.CFrame = CFrame.new(-90 + math.random() * 55, -6, 842 + math.random() * 8) * CFrame.Angles(math.random(), math.random(), math.random())
			r.Color = Color3.fromRGB(85, 80, 72)
			r.Material = Enum.Material.Rock
			r.CanQuery = false
			r.Parent = workspace
			table.insert(rocks, r)
			if spawned % 8 == 0 then
				sound(Config.Sounds.Jumpscare, 0.4, 0.3)
			end
		end
	end)
	task.delay(6, function()
		for _, r in rocks do
			r:Destroy()
		end
	end)
end
function cutscenes.monitors(args)
	local screens = {}
	local mon = level.Parent.Subway.Control:FindFirstChild("Monitors")
	if mon then
		for _, sc in mon:GetChildren() do
			if sc.Name == "Screen" then
				table.insert(screens, sc)
			end
		end
	end
	local saved = {}
	for _, sc in screens do
		local l = sc.Gui.Text
		saved[sc] = { l.Text, l.TextColor3, sc.Color }
	end
	local lit = 0
	local turned = false
	timeline(11, {
		{ 0, 8.2, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-84, -28.5, 1066), Vector3.new(-99, -28.5, 1066)), CFrame.lookAt(Vector3.new(-90, -28.6, 1066), Vector3.new(-99, -28.6, 1066)), k) end },
		{ 8.2, 9.2, function(k) return CFrame.lookAt(Vector3.new(-90, -28.6, 1066), Vector3.new(-99, -28.6, 1066)):Lerp(CFrame.lookAt(Vector3.new(-90, -28.6, 1066), Vector3.new(-80, -29, 1066)), k * k) end },
		{ 9.2, 11, function(k) return CFrame.lookAt(Vector3.new(-90, -28.6, 1066), Vector3.new(-80, -29, 1066)) end },
	}, {
		{ 0.3, "Hello again, employee.", "DIRECTOR MARSH (every screen)" },
		{ 3, "You came such a long way. Through MY tunnels.", "DIRECTOR MARSH" },
		{ 5.6, "Do you even know what's been following you down here?", "DIRECTOR MARSH" },
		{ 7.6, "...Turn around.", "DIRECTOR MARSH" },
		{ 9.4, "...Nothing. Just the dark." },
	}, false, function(t)
		local want = math.clamp(math.floor(t * 4), 0, #screens)
		while lit < want do
			lit += 1
			local sc = screens[lit]
			sc.Color = Color3.fromRGB(70, 10, 10)
			sc.Gui.Text.TextColor3 = Color3.fromRGB(255, 80, 70)
			sc.Gui.Text.Text = lit == 7 and "CAM 07\nYOUR LOCATION\n(SOMETHING BEHIND YOU)" or "I SEE YOU"
		end
		if t >= 8.2 and not turned then
			turned = true
			sound(Config.Sounds.Jumpscare, 0.9, 0.8)
		end
	end)
	for sc, v in saved do
		sc.Gui.Text.Text, sc.Gui.Text.TextColor3, sc.Color = v[1], v[2], v[3]
	end
end
function cutscenes.depart(args)
	local last = level.Parent.Subway.LastStop
	local parts = {}
	for _, n in { "TrainA", "TrainB", "TrainC" } do
		local m = last:FindFirstChild(n)
		if m then
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then
					parts[p] = p.CFrame
				end
			end
		end
	end
	timeline(9, {
		{ 0, 3, function(k) return CFrame.lookAt(Vector3.new(-50, -25, 1200), Vector3.new(-66, -26, 1205)) end },
		{ 3, 9, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-48, -24, 1140), Vector3.new(-70, -26, 1200)), CFrame.lookAt(Vector3.new(-48, -24, 1150), Vector3.new(-70, -26, 1230)), k) end },
	}, {
		{ 0.3, "The doors hiss shut behind you." },
		{ 3.2, "The last train pulls out of the Last Stop..." },
		{ 6.5, "...and for a moment, everything is quiet." },
	}, false, function(t)
		if t > 3 then
			local dz = 3 * (t - 3) ^ 2
			for p, home in parts do
				p.CFrame = home + Vector3.new(0, 0, dz)
			end
		end
	end)
	for p, home in parts do
		p.CFrame = home
	end
end
function cutscenes.lobby(args)
	local items = workspace:FindFirstChild("Items")
	local function hideLobbyMarsh(h)
		local m = items and items:FindFirstChild("LobbyMarsh")
		if m then
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = h and 1 or 0
				end
			end
		end
	end
	local stand = Vector3.new(0, 0, -25)
	local from = Vector3.new(9, 0, -12)
	local marsh = makeActor(views:FindFirstChild("Marsh"), from, stand)
	actorBase(marsh, mcfg.walk, 0.6)
	local g1 = makeActor(views:FindFirstChild("Guard"), Vector3.new(-4, 0, -21), stand)
	local g2 = makeActor(views:FindFirstChild("Guard"), Vector3.new(4.5, 0, -20), stand)
	actorBase(g1, gcfg.idle, 1)
	actorBase(g2, gcfg.idle, 1)
	local stage = 0
	timeline(12, {
		{ 0, 5, function(k) return CFrame.lookAt(Vector3.new(-2, 5.4, 4.6), Vector3.new(1, 4.2, -18)) * CFrame.new((math.random() - 0.5) * 0.03, 0, 0) end },
		{ 5, 12, function(k)
			local head = actorHead(marsh, stand + Vector3.new(0, 4.8, 0))
			return lerpCF(CFrame.lookAt(Vector3.new(-1.5, 5.4, -8), head), CFrame.lookAt(Vector3.new(-0.8, 5.2, -15), head), k)
		end },
	}, {
		{ 0.3, "*Through the gap in the elevator doors...*" },
		{ 2, "Twelve floors, forty men, and NOBODY can find one ex-employee?", "DIRECTOR MARSH" },
		{ 5.4, "Sir - the elevator's been dead since we cut the power.", "SWAT" },
		{ 7.4, "Then check the stairs AGAIN. Seal every exit.", "DIRECTOR MARSH" },
		{ 9.8, "They are NOT leaving this building.", "DIRECTOR MARSH" },
	}, false, function(t)
		hideLobbyMarsh(true)
		if t < 4.5 then
			actorWalk(marsh, from, stand, t / 4.5)
		elseif stage == 0 then
			stage = 1
			actorBase(marsh, mcfg.idle, 1)
			actorPlace(marsh, stand, Vector3.new(0, 0, 0))
		end
		if t >= 7.4 and stage == 1 then
			stage = 2
			actorPlace(marsh, stand, Vector3.new(-4, 0, -21))
			actorGesture(marsh, ANIM.point, false, 0.9)
		end
	end)
	hideLobbyMarsh(false)
end
remotes:WaitForChild("Cutscene").OnClientEvent:Connect(function(name, args)
	local f = cutscenes[name]
	if not f then
		return
	end
	if mgKind then
		mgKind = nil
		mgRoot.Visible = false
		minigameOpen = false
		mgClean()
	end
	beginCut()
	local ok, err = pcall(f, args or {})
	if not ok then
		warn("Cutscene " .. name .. ": " .. tostring(err))
	end
	clearActors()
	hideReal("Marsh", false)
	endCut()
end)
-- ZIPLINE ride camera
remotes:WaitForChild("Zip").OnClientEvent:Connect(function(from, to, dur)
	beginCut()
	letterTop.Visible, letterBot.Visible = false, false
	camera.FieldOfView = 85
	local t0 = os.clock()
	sub.Text = ""
	while os.clock() - t0 < dur do
		local k = (os.clock() - t0) / dur
		local pos = from:Lerp(to, k) - Vector3.new(0, 3, 0)
		camera.CFrame = CFrame.lookAt(pos - (to - from).Unit * 4 + Vector3.new(0, 2, 0), to) * CFrame.new(math.sin(os.clock() * 30) * 0.05, math.sin(os.clock() * 23) * 0.05, 0)
		RunService.Heartbeat:Wait()
	end
	endCut()
end)

-- ENDING --------------------------------------------------------------------------------
remotes:WaitForChild("Ending").OnClientEvent:Connect(function(secs, tapes, difficulty)
	beginCut()
	fade(0, 0.8)
	task.wait(0.9)
	-- dawn by the sea (local lighting only)
	_G.Ch4Cinematic = true
	local L = Lighting
	local saved = { ClockTime = L.ClockTime, Brightness = L.Brightness, Ambient = L.Ambient, OutdoorAmbient = L.OutdoorAmbient, FogEnd = L.FogEnd, FogStart = L.FogStart, FogColor = L.FogColor }
	local atm = L:FindFirstChildOfClass("Atmosphere") or _G.Ch4Atm
	local atmWasParent = atm and atm.Parent
	local atmSaved = atm and { Density = atm.Density, Color = atm.Color, Decay = atm.Decay, Haze = atm.Haze }
	local grade = L:FindFirstChild("Ch4Grade")
	local coast = workspace:FindFirstChild("Coast")
	local train = coast and coast:FindFirstChild("EscapeTrain")
	local trainHome = {}
	if train then
		for _, p in train:GetDescendants() do
			if p:IsA("BasePart") then
				trainHome[p] = p.CFrame
			end
		end
	end
	local X = 3000
	timeline(5, {
		{ 0, 5, function(k) return lerpCF(CFrame.lookAt(Vector3.new(1000, -196, 90), Vector3.new(1001, -196.6, 96.5)), CFrame.lookAt(Vector3.new(1000.6, -196.4, 93.8), Vector3.new(1001, -196.6, 96.5)), k) end },
	}, {
		{ 0.3, "The map is still warm from the cab's heater. One island, circled in red." },
	})
	fade(0, 0.5)
	task.wait(0.6)
	L.ClockTime = 6.1
	L.Brightness = 1.6
	L.Ambient = Color3.fromRGB(60, 55, 60)
	L.OutdoorAmbient = Color3.fromRGB(150, 120, 110)
	L.FogStart, L.FogEnd = 0, 100000
	if atm then
		atm.Parent = L
		atm.Density, atm.Color, atm.Decay, atm.Haze = 0.42, Color3.fromRGB(215, 170, 150), Color3.fromRGB(110, 90, 100), 2
	end
	if grade then
		grade.TintColor, grade.Saturation, grade.Contrast, grade.Brightness = Color3.fromRGB(255, 232, 215), 0, 0.08, 0.02
	end
	fade(1, 1.5)
	timeline(22, {
		-- the train bursts out of the cliff
		{ 0, 7, function(k) return lerpCF(CFrame.lookAt(Vector3.new(X + 26, 4, 70), Vector3.new(X, 6, 10)), CFrame.lookAt(Vector3.new(X + 24, 5, 80), Vector3.new(X, 5, 60)), k) end },
		-- alongside, the sea behind it
		{ 7, 14, function(k) return lerpCF(CFrame.lookAt(Vector3.new(X - 30, 14, 150), Vector3.new(X + 60, 4, 200)), CFrame.lookAt(Vector3.new(X - 26, 16, 210), Vector3.new(X + 200, 10, 260)), k) end },
		-- the island in the mist
		{ 14, 22, function(k) return lerpCF(CFrame.lookAt(Vector3.new(X + 30, 8, 240), Vector3.new(X + 700, 60, 265)), CFrame.lookAt(Vector3.new(X + 60, 10, 248), Vector3.new(X + 715, 100, 270)), k) end },
	}, {
		{ 0.5, "The last train bursts out of the dark... into grey morning light." },
		{ 4.2, "The sea. You'd forgotten what open air smells like." },
		{ 8, "Behind you, the city. Wildcrest's city." },
		{ 11.5, "Ahead, on the horizon..." },
		{ 14.5, "...an island. 'B-02 HOLDING'. And a red light that never stops blinking." },
		{ 18.5, "Wildcrest wants you on that island. Then that's where this ends." },
	}, false, function(t)
		if train then
			local dz = math.max(0, t) * 22
			for p, home in trainHome do
				p.CFrame = home + Vector3.new(0, 0, dz)
			end
		end
	end)
	fade(0, 1)
	task.wait(1)
	title.Text = "CHAPTER 4 - COMPLETE"
	titleSub.Text = ("Time %d:%02d   |   %s   |   NEXT: CHAPTER 5 - THE ISLAND (the finale)   |   Returning to the lobby..."):format(secs // 60, secs % 60, string.upper(difficulty or "Normal"))
	task.wait(6)
	-- put everything back (Studio restarts the round instead of teleporting)
	for k, v in saved do
		L[k] = v
	end
	if atm and atmSaved then
		for k, v in atmSaved do
			atm[k] = v
		end
		atm.Parent = atmWasParent
	end
	for p, home in trainHome do
		p.CFrame = home
	end
	_G.Ch4Cinematic = false
end)

-- ATMOSPHERE: alarm, blackout, flickering lights -----------------------------------------
local alarmSound = Instance.new("Sound")
alarmSound.SoundId = Config.Sounds.Alarm
alarmSound.Looped = true
alarmSound.Volume = 0.35
alarmSound.Parent = gui
local redFlash = frame(overlay, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 0, 0), BackgroundTransparency = 1, ZIndex = 2 })
local alarmUntil = 0
RS:GetAttributeChangedSignal("Alarm"):Connect(function()
	if RS:GetAttribute("Alarm") then
		alarmUntil = os.clock() + 25
		alarmSound:Play()
	else
		alarmSound:Stop()
	end
end)
local lightParts = {}
for _, p in level:GetDescendants() do
	if p:IsA("PointLight") or p:IsA("SpotLight") or p:IsA("SurfaceLight") then
		table.insert(lightParts, p)
	end
end
local saved
local function lightPos(l)
	local p = l.Parent
	if p and p:IsA("BasePart") then
		return p.Position
	elseif p and p:IsA("Attachment") then
		return p.WorldPosition
	end
	return Vector3.zero
end
setBlackout = function(on, waveCenter)
	if on then
		if saved then
			return
		end
		saved = { Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime }
		for _, l in lightParts do
			l:SetAttribute("WasOn", l.Enabled)
		end
		local mine = saved
		local function dark()
			if saved ~= mine then
				return
			end
			Lighting.Ambient = Color3.fromRGB(18, 16, 22)
			Lighting.OutdoorAmbient = Color3.fromRGB(40, 36, 44)
			Lighting.Brightness = 0.6
		end
		if waveCenter then
			-- lights die one by one, closing in on you
			local list = table.clone(lightParts)
			table.sort(list, function(a, b)
				return (lightPos(a) - waveCenter).Magnitude > (lightPos(b) - waveCenter).Magnitude
			end)
			task.spawn(function()
				local step = math.max(1, math.floor(#list / 22))
				for i, l in list do
					if saved ~= mine then
						return
					end
					l.Enabled = false
					if i % step == 0 then
						task.wait(0.09)
					end
					if i == math.floor(#list / 2) then
						dark()
					end
				end
				dark()
			end)
		else
			for _, l in lightParts do
				l.Enabled = false
			end
			dark()
		end
		notice("Everything goes dark. Turn on your flashlight [F].", Color3.fromRGB(255, 200, 120), 5)
		flashlightOn = true
	elseif saved then
		local savedLighting = saved
		saved = nil
		for _, l in lightParts do
			if l:GetAttribute("WasOn") ~= nil then
				l.Enabled = l:GetAttribute("WasOn")
				l:SetAttribute("WasOn", nil)
			end
		end
		for k, v in savedLighting or {} do
			Lighting[k] = v
		end
		local sec = level:FindFirstChild("Rooms") and level.Rooms:FindFirstChild("Security")
		local lever = sec and sec:FindFirstChild("BreakerLever")
		local hinge = lever and lever:GetAttribute("Hinge")
		if hinge then
			lever.CFrame = hinge * CFrame.new(0, 0.65, 0)
		end
	end
end
RS:GetAttributeChangedSignal("SignalCut"):Connect(function()
	local cable = level:FindFirstChild("Roof") and level.Roof:FindFirstChild("Cable")
	if cable and not RS:GetAttribute("SignalCut") and cable:GetAttribute("OrigCF") then
		cable.CFrame = cable:GetAttribute("OrigCF")
		cable.Size = Vector3.new(cable.Size.X, cable.Size.Y, 9)
	end
end)
RS:GetAttributeChangedSignal("Blackout"):Connect(function()
	setBlackout(RS:GetAttribute("Blackout") == true)
end)
local flick = CollectionService:GetTagged("Flicker")
local beacons = CollectionService:GetTagged("Blink")
local heartbeat = Instance.new("Sound")
heartbeat.SoundId = Config.Sounds.Heartbeat
heartbeat.Looped = true
heartbeat.Volume = 0
heartbeat.Parent = gui
heartbeat:Play()
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	if t < alarmUntil then
		redFlash.BackgroundTransparency = 0.88 + 0.1 * math.abs(math.sin(t * 3))
	else
		redFlash.BackgroundTransparency = 1
		if alarmSound.IsPlaying and t > alarmUntil then
			alarmSound:Stop()
		end
	end
	if not RS:GetAttribute("Blackout") then
		for _, p in flick do
			local l = p:FindFirstChildWhichIsA("Light")
			if l then
				l.Enabled = math.noise(t * 3, p.Position.X) > -0.35
			end
		end
	end
	for _, b in beacons do
		b.Transparency = (math.floor(t * 1.5) % 2 == 0) and 0 or 0.7
	end
	-- heartbeat when something is hunting you nearby
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local close = 999
	if myRoot then
		local mf = workspace:FindFirstChild("Monsters")
		for _, m in mf and mf:GetChildren() or {} do
			if m.PrimaryPart and m:GetAttribute("Chasing") == player.Name then
				close = math.min(close, (m.PrimaryPart.Position - myRoot.Position).Magnitude)
			end
		end
	end
	heartbeat.Volume = close < 60 and (1 - close / 60) * 1.4 or 0
	heartbeat.PlaybackSpeed = close < 25 and 1.4 or 1
end)
-- B-01 in the vents
remotes:WaitForChild("Vent").OnClientEvent:Connect(function(pos, what)
	local p = Instance.new("Part")
	p.Anchored = true p.CanCollide = false p.CanQuery = false p.Transparency = 1 p.Position = pos p.Parent = workspace
	local s = Instance.new("Sound")
	s.SoundId = Config.Sounds.Growl s.Volume = 2 s.PlaybackSpeed = what == "in" and 1.3 or 0.7 s.RollOffMaxDistance = 90 s.Parent = p
	s:Play()
	game:GetService("Debris"):AddItem(p, 6)
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if myRoot and (myRoot.Position - pos).Magnitude < 60 then
		notice(what == "in" and "Something just crawled into the vents..." or "The vent grate bursts open nearby!", Color3.fromRGB(255, 110, 90))
	end
end)

-- OBJECTIVE MARKER [H] --------------------------------------------------------------------
do
	local on = true
	local bb = Instance.new("BillboardGui")
	bb.Name = "ObjectiveMarker"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(160, 46)
	bb.LightInfluence = 0
	bb.Enabled = false
	bb.Parent = player.PlayerGui
	local dia = frame(bb, { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Rotation = 45, BackgroundColor3 = Color3.fromRGB(255, 210, 110) })
	local txt = label(bb, { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 18), Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(255, 225, 160) })
	local hint = label(gui, { Size = UDim2.fromOffset(170, 18), Position = UDim2.new(1, -194, 0, 76), TextSize = 13, TextColor3 = Color3.fromRGB(170, 170, 170), Text = "Objective marker [H]", TextXAlignment = Enum.TextXAlignment.Right })
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.H then
			on = not on
			hint.Text = on and "Objective marker [H]" or "Marker hidden [H]"
		end
	end)
	local function tagged(tag, filter)
		for _, p in CollectionService:GetTagged(tag) do
			if not filter or filter(p) then
				return p
			end
		end
	end
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Name = "MarkerAnchor"
	anchor.Parent = workspace.CurrentCamera
	local function target()
		local pos = RS:GetAttribute("MarkerPos")
		if typeof(pos) ~= "Vector3" then
			return nil
		end
		anchor.Position = pos
		return anchor, RS:GetAttribute("MarkerName")
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local part, name = target()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local show = on and part ~= nil and root ~= nil and gui.Enabled and not introPlaying
		bb.Enabled = show
		if show then
			bb.Adornee = part
			bb.StudsOffset = Vector3.new(0, 3, 0)
			local d = (part.Position - root.Position).Magnitude
			local fl = part.Position.Y < -3 and "UNDERGROUND" or (part.Position.Y < 8 and "GROUND" or ("FLOOR " .. (math.floor((part.Position.Y + 3) / 14) + 1)))
			txt.Text = ("%s (%s)  %dm"):format(name or "", fl, math.floor(d / 3.5))
			bb.Enabled = d > 8
		end
	end)
end

-- LIVE RAIL ZAP + UNDERGROUND DARKNESS --------------------------------------------------
do
	local flash = frame(overlay, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(220, 240, 255), BackgroundTransparency = 1, ZIndex = 3 })
	remotes:WaitForChild("State").OnClientEvent:Connect(function(what)
		if what == "zap" then
			flash.BackgroundTransparency = 0.1
			TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
			sound(Config.Sounds.Jumpscare, 0.4, 2.2)
		end
	end)
	local baseAmbient, baseBright = Lighting.Ambient, Lighting.Brightness
	local under = false
	local savedAtm
	RunService.Heartbeat:Connect(function()
		if _G.Ch4Cinematic then
			return
		end
		local u = camera.CFrame.Position.Y < -6
		if u ~= under then
			under = u
			Lighting.Ambient = u and Color3.fromRGB(48, 48, 56) or baseAmbient
			Lighting.Brightness = u and 1 or baseBright
			-- outdoor fog gets thicker the deeper you go: switch it off underground
			savedAtm = savedAtm or Lighting:FindFirstChildOfClass("Atmosphere")
			_G.Ch4Atm = savedAtm
			if savedAtm then
				savedAtm.Parent = (not u) and Lighting or nil
			end
			Lighting.FogColor = Color3.fromRGB(16, 17, 20)
			Lighting.FogStart = u and 40 or 0
			Lighting.FogEnd = u and 260 or 100000
		end
	end)
end

-- RUNAWAY TRAINS (warning + rumble) --------------------------------------------------------
do
	local shakeUntil, shakeStart = 0, 0
	remotes:WaitForChild("State").OnClientEvent:Connect(function(what, zStart, dir, warnTime)
		if what ~= "train" then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or root.Position.Z < 240 or root.Position.Y > -24 then
			return
		end
		notice("A TRAIN IS COMING " .. (dir > 0 and "FROM BEHIND" or "FROM AHEAD") .. "!  GET INTO AN ALCOVE!", Color3.fromRGB(255, 230, 120), 5)
		sound(Config.Sounds.Alarm, 0.9, 0.45)
		shakeStart = os.clock()
		shakeUntil = os.clock() + (warnTime or 4) + 7
	end)
	RunService:BindToRenderStep("TrainShake", Enum.RenderPriority.Camera.Value + 1, function()
		local now = os.clock()
		if now < shakeUntil and camera.CameraType ~= Enum.CameraType.Scriptable then
			local k = math.clamp((now - shakeStart) / 4, 0, 1) * 0.12
			camera.CFrame = camera.CFrame * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
		end
	end)
end

-- QUAKES + THE RIDE ------------------------------------------------------------------------
do
	local qUntil, qAmp = 0, 0
	remotes:WaitForChild("State").OnClientEvent:Connect(function(what)
		if what == "quake" or what == "uncouple" then
			qUntil = os.clock() + (what == "uncouple" and 3 or 1.6)
			qAmp = what == "uncouple" and 0.35 or 0.25
			sound(Config.Sounds.Jumpscare, 0.5, what == "uncouple" and 0.6 or 0.35)
			if what == "uncouple" then
				notice("CLUNK - the coupling releases! The back cars fall away into the dark...", Color3.fromRGB(255, 220, 120), 5)
			end
		end
	end)
	RunService:BindToRenderStep("QuakeShake", Enum.RenderPriority.Camera.Value + 2, function()
		if os.clock() < qUntil and camera.CameraType ~= Enum.CameraType.Scriptable then
			local a = qAmp * (qUntil - os.clock()) / 2
			camera.CFrame = camera.CFrame * CFrame.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
		end
	end)
	-- lights flying past the windows
	local lights = {}
	local folder = Instance.new("Folder")
	folder.Name = "RideFX"
	folder.Parent = workspace.CurrentCamera
	for i = 1, 14 do
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Size = Vector3.new(0.4, 0.4, 3)
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 220, 160)
		p.Transparency = 1
		local l = Instance.new("PointLight")
		l.Range = 12
		l.Brightness = 1.4
		l.Color = p.Color
		l.Enabled = false
		l.Parent = p
		p.Parent = folder
		lights[i] = { part = p, light = l, z = -40 + i * 13, side = (i % 2 == 0) and 11.6 or -11.6 }
	end
	local rumble = Instance.new("Sound")
	rumble.SoundId = Config.Sounds.Heartbeat
	rumble.Looped = true
	rumble.PlaybackSpeed = 0.35
	rumble.Volume = 0
	rumble.Parent = gui
	rumble:Play()
	RunService.Heartbeat:Connect(function(dt)
		local on = RS:GetAttribute("Riding") == true and camera.CFrame.Position.Y < -150
		rumble.Volume = on and 0.6 or 0
		for _, L in lights do
			L.part.Transparency = on and 0 or 1
			L.light.Enabled = on
			if on then
				L.z -= 75 * dt
				if L.z < -40 then
					L.z += 180
				end
				L.part.CFrame = CFrame.new(1000 + L.side, -194, L.z)
			end
		end
	end)
end

-- LOOK: colour grade + vignette per area ----------------------------------------------------
do
	local grade = Lighting:FindFirstChild("Ch4Grade") or Instance.new("ColorCorrectionEffect")
	grade.Name = "Ch4Grade"
	grade.Parent = Lighting
	local zones = {
		{ "ride", function(p) return p.Y < -150 end, { Color3.fromRGB(250, 235, 228), -0.12, 0.08, 0.05, 0.3 } },
		{ "sewer", function(p) return p.Y < -45 end, { Color3.fromRGB(220, 240, 222), -0.25, 0.08, 0.06, 0.35 } },
		{ "control", function(p) return p.Y < -6 and p.Z > 1028 and p.Z < 1101 end, { Color3.fromRGB(222, 230, 255), -0.18, 0.08, 0.06, 0.3 } },
		{ "laststop", function(p) return p.Y < -6 and p.Z >= 1101 end, { Color3.fromRGB(255, 236, 220), -0.1, 0.07, 0.06, 0.25 } },
		{ "construction", function(p) return p.Y < -6 and p.Z > 703 and p.Z < 882 end, { Color3.fromRGB(255, 235, 210), -0.15, 0.08, 0.06, 0.3 } },
		{ "tunnel", function(p) return p.Y < -6 and p.Z > 244 end, { Color3.fromRGB(215, 222, 230), -0.3, 0.1, 0.05, 0.4 } },
		{ "station", function(p) return p.Y < -3 end, { Color3.fromRGB(232, 245, 226), -0.2, 0.07, 0.06, 0.3 } },
		{ "tower", function(p) return p.X > -41 and p.X < 41 and p.Z > -31 and p.Z < 31 and p.Y < 170 end, { Color3.fromRGB(255, 244, 232), 0, 0.03, 0.04, 0.12 } },
		{ "city", function() return true end, { Color3.fromRGB(225, 232, 255), -0.05, 0.05, 0.04, 0.18 } },
	}
	local vg = Instance.new("ScreenGui")
	vg.Name = "Vignette"
	vg.IgnoreGuiInset = true
	vg.ResetOnSpawn = false
	vg.DisplayOrder = -1
	vg.Parent = player.PlayerGui
	local edges = {}
	for _, e in { { UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0), 90 }, { UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.7), -90 }, { UDim2.fromScale(0.25, 1), UDim2.fromScale(0, 0), 0 }, { UDim2.fromScale(0.25, 1), UDim2.fromScale(0.75, 0), 180 } } do
		local f = Instance.new("Frame")
		f.Size, f.Position = e[1], e[2]
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.Parent = vg
		local g = Instance.new("UIGradient")
		g.Rotation = e[3]
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		table.insert(edges, f)
	end
	local current
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		if _G.Ch4Cinematic then
			current = nil
			return
		end
		local pos = camera.CFrame.Position
		for _, z in zones do
			if z[2](pos) then
				if current ~= z[1] then
					current = z[1]
					local v = z[3]
					TweenService:Create(grade, TweenInfo.new(1.5), { TintColor = v[1], Saturation = v[2], Contrast = v[3], Brightness = v[4] }):Play()
					for _, f in edges do
						TweenService:Create(f, TweenInfo.new(1.5), { BackgroundTransparency = 1 - v[5] }):Play()
					end
				end
				break
			end
		end
	end)
end

-- THE CRAWLER: procedural bone animation (it has no animation clips of its own) -------------
do
	local rigs = {} -- [model] = { bones = {name = {bone, base}}, last = pos, phase = 0, twitchAt = 0, twitch = CFrame }
	local function setup(m)
		if rigs[m] or not m:GetAttribute("BoneRig") then
			return
		end
		local bones = {}
		for _, b in m:GetDescendants() do
			if b:IsA("Bone") then
				bones[b.Name] = b
			end
		end
		rigs[m] = { bones = bones, last = nil, phase = math.random() * 6, twitchAt = 0, tw = CFrame.new() }
	end
	local function scan()
		for _, folder in { workspace:FindFirstChild("Monsters"), workspace } do
			if folder then
				for _, m in folder:GetChildren() do
					if m:IsA("Model") and m:GetAttribute("BoneRig") then
						setup(m)
					end
				end
			end
		end
	end
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc > 1 then
			acc = 0
			scan()
		end
		local now = os.clock()
		for m, r in rigs do
			if not m.Parent then
				rigs[m] = nil
				continue
			end
			local root = m.PrimaryPart
			if not root then
				continue
			end
			-- positions arrive from the server in steps, so measure speed over a short window
			local pos = root.Position
			r.sampleT = r.sampleT or now
			r.samplePos = r.samplePos or pos
			if now - r.sampleT >= 0.25 then
				local measured = ((pos - r.samplePos) * Vector3.new(1, 0, 1)).Magnitude / (now - r.sampleT)
				r.speedTarget = measured
				r.sampleT, r.samplePos = now, pos
			end
			r.speed = (r.speed or 0) + ((r.speedTarget or 0) - (r.speed or 0)) * math.min(1, dt * 6)
			local speed = r.speed
			local stunned = m:GetAttribute("Stunned")
			local k = math.clamp(speed / 14, 0, 1.4)
			r.phase += dt * (2 + speed * 0.55)
			local p = r.phase
			local b = r.bones
			local function rot(name, x, y, z)
				local bone = b[name]
				if bone then
					bone.Transform = CFrame.Angles(x, y, z)
				end
			end
			if stunned then
				-- shaking, curled up
				local sh = (math.random() - 0.5) * 0.25
				rot("Spine", 0.5 + sh, 0, sh)
				rot("Head", 0.4, sh * 2, 0)
				rot("LeftArm", 0.9, 0, 0.4)
				rot("RightArm", 0.9, 0, -0.4)
				continue
			end
			-- crawl cycle: opposite limbs together
			local swing = math.sin(p) * 0.65 * k
			rot("LeftUpLeg", swing, 0, 0)
			rot("RightUpLeg", -swing, 0, 0)
			rot("LeftLeg", math.max(0, -math.sin(p)) * 0.8 * k, 0, 0)
			rot("RightLeg", math.max(0, math.sin(p)) * 0.8 * k, 0, 0)
			rot("LeftArm", -swing * 1.2 - 0.2 * k, 0, 0)
			rot("RightArm", swing * 1.2 - 0.2 * k, 0, 0)
			rot("LeftForeArm", math.max(0, math.sin(p)) * 0.7 * k, 0, 0)
			rot("RightForeArm", math.max(0, -math.sin(p)) * 0.7 * k, 0, 0)
			-- breathing / body bob
			local breath = math.sin(now * 1.7) * 0.06
			rot("Spine02", breath + math.sin(p * 2) * 0.08 * k, 0, math.sin(p) * 0.06 * k)
			rot("Spine01", breath, math.sin(p) * 0.08 * k, 0)
			-- the head: slow searching sway + sudden twitches
			if now > r.twitchAt then
				r.twitchAt = now + (k > 0.5 and 0.6 or 1.4) + math.random() * 1.8
				r.tw = CFrame.Angles((math.random() - 0.5) * 0.9, (math.random() - 0.5) * 1.3, (math.random() - 0.5) * 0.9)
				r.twEnd = now + 0.12 + math.random() * 0.15
			end
			local head = b["Head"]
			if head then
				local sway = CFrame.Angles(math.sin(now * 0.9) * 0.15, math.sin(now * 0.6) * 0.35, 0)
				head.Transform = sway * ((r.twEnd and now < r.twEnd) and r.tw or CFrame.new())
			end
			rot("neck", math.sin(now * 0.8) * 0.1, 0, math.sin(now * 1.3) * 0.08)
		end
	end)
end

-- FIRST PERSON: free the mouse whenever something needs clicking (minigames, notes, menus) or M is toggled
do
	local freeMouse = false
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			freeMouse = not freeMouse
		end
	end)
	RunService:BindToRenderStep("FreeMouse", Enum.RenderPriority.Camera.Value + 10, function()
		local needMouse = freeMouse or minigameOpen or paper.Visible or picker.Visible or player:GetAttribute("AdminPanelOpen") == true
		if needMouse then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
	end)
end

-- CASH + SIXTH SENSE -------------------------------------------------------------------------
do
	local cashLabel = label(gui, { Size = UDim2.fromOffset(240, 26), Position = UDim2.new(1, -264, 0, 100), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 20, TextColor3 = Color3.fromRGB(130, 255, 150), Text = "" })
	local function refreshCash()
		local c = player:GetAttribute("RunCash") or 0
		cashLabel.Text = c > 0 and ("$%d this run"):format(c) or ""
	end
	player:GetAttributeChangedSignal("RunCash"):Connect(refreshCash)
	refreshCash()
	local senseLabel = label(gui, { Size = UDim2.fromOffset(300, 22), Position = UDim2.new(0, 24, 1, -150), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, TextColor3 = Color3.fromRGB(220, 160, 255), Text = "" })
	local readyAt = 0
	local function refreshSense()
		if not player:GetAttribute("Up_Sixth") then
			senseLabel.Text = ""
		elseif os.clock() < readyAt then
			senseLabel.Text = ("SIXTH SENSE [R]: %ds"):format(math.ceil(readyAt - os.clock()))
		else
			senseLabel.Text = "SIXTH SENSE [R]: ready"
		end
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.R or not player:GetAttribute("Up_Sixth") or os.clock() < readyAt or cutscenePlaying then
			return
		end
		readyAt = os.clock() + 30
		sound(Config.Sounds.Heartbeat, 0.8, 0.6)
		local folder = workspace:FindFirstChild("Monsters")
		local hl = {}
		if folder then
			for _, m in folder:GetChildren() do
				local h = Instance.new("Highlight")
				h.Adornee = m
				h.FillColor = Color3.fromRGB(200, 60, 255)
				h.FillTransparency = 0.6
				h.OutlineColor = Color3.fromRGB(240, 200, 255)
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.Parent = camera
				table.insert(hl, h)
			end
		end
		notice("Sixth Sense: you can feel where they are...", Color3.fromRGB(220, 160, 255), 3)
		task.delay(4, function()
			for _, h in hl do
				h:Destroy()
			end
		end)
	end)
	RunService.Heartbeat:Connect(refreshSense)
end
