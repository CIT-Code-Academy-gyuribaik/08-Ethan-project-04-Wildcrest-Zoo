-- CHAPTER 3: WILDCREST HQ - client
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
local level = workspace:WaitForChild("HQ")
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
	local ev, need = RS:GetAttribute("Evidence") or 0, RS:GetAttribute("EvidenceNeeded") or 8
	local function box(done)
		return done and "[x] " or "[ ] "
	end
	local lines = {
		box(ev >= need) .. ("Evidence %d/%d (3 floors)"):format(math.min(ev, need), need),
		box(RS:GetAttribute("Keycard1")) .. "Guard keycard (Security)",
		box(phase >= 3) .. ("Free the subjects %d/3 (Containment)"):format(RS:GetAttribute("CellsFreed") or 0),
		box(RS:GetAttribute("Keycard2")) .. "Marsh's safe -> Level 2 card",
		box(phase >= 4) .. "Upload evidence (Server Room)",
		box(phase >= 5) .. "Boot the transmitter (floor 3)",
		box(RS:GetAttribute("SignalCut")) .. "Roof: align dish + broadcast",
		box(false) .. "Escape",
	}
	local tapes = RS:GetAttribute("Tapes") or 0
	if tapes > 0 then
		table.insert(lines, ("     (secret tapes %d/6)"):format(tapes))
	end
	return table.concat(lines, "\n")
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
for _, a in { "Objective", "Phase", "Evidence", "EvidenceNeeded", "Keycard1", "Keycard2", "CellsFreed", "SignalCut", "Tapes", "Difficulty", "Broadcast", "BroadcastStalled" } do
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
	hum.WalkSpeed = speed * (player:GetAttribute("AdminSpeed") or 1)
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
	scareText.Text = kind == "Guard" and "TASERED!" or (kind == "Marsh" and "\"GOTCHA.\"" or "IT GOT YOU")
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

-- SNEAKING IN (plays right after the intro) ----------------------------------------------
playSneak = function()
	sub.Text = ""
	local win = Vector3.new(-14, 0, 80.5)
	local out0, out1 = Vector3.new(-3, 0, 103), Vector3.new(-14, 0, 84.8)
	local crate, sill, inside = Vector3.new(-14, 1.4, 83.2), Vector3.new(-14, 2, 80.6), Vector3.new(-14, 0, 77)
	local me = makeActor(player.Character, out0, out1)
	local guard = makeActor(views:FindFirstChild("Guard"), Vector3.new(13, 0, 63.5), Vector3.new(-10, 0, 63.5))
	if guard then
		local beam = Instance.new("SpotLight")
		beam.Face = Enum.NormalId.Front
		beam.Range = 45
		beam.Angle = 38
		beam.Brightness = 5
		beam.Shadows = true
		beam.Color = Color3.fromRGB(255, 245, 220)
		beam.Parent = guard.root
	end
	local gcfg = Config.Monsters.Guard.Anim
	local mePos = out0
	local stage = 0
	local g0, g1 = Vector3.new(13, 0, 63.5), Vector3.new(-5, 0, 62.5)
	timeline(15, {
		{ 0, 4.5, function(k) return CFrame.lookAt(Vector3.new(-27, 4.5, 97), mePos + Vector3.new(0, 3, 0)) end },
		{ 4.5, 7, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-23, 5, 92.5), out1 + Vector3.new(0, 4, 0)), CFrame.lookAt(Vector3.new(-21, 5, 90.5), out1 + Vector3.new(0, 4, 0)), k) end },
		{ 7, 10, function(k) return CFrame.lookAt(Vector3.new(-7.5, 4, 71), mePos + Vector3.new(0, 3, 0)) end },
		{ 10, 15, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-18.8, 5.8, 79.3), Vector3.new(3, 3, 61)), CFrame.lookAt(Vector3.new(-18.2, 5.4, 78.4), Vector3.new(1, 3, 61)), k) end },
	}, {
		{ 0.3, "The front doors have cameras. But one lobby window was smashed weeks ago - and nobody ever fixed it." },
		{ 4.6, "...Clear. Nobody's watching.", "YOU" },
		{ 7.1, "*glass crunches under your shoes*" },
		{ 10.2, "FBI?! Wildcrest hired the FBI to guard this place?", "YOU" },
		{ 12.8, "Stay out of their flashlights. Find the evidence." },
	}, true, function(t)
		local real = player.Character
		if real then
			for _, p in real:GetDescendants() do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = 1
				end
			end
		end
		if t < 4.5 then
			if stage ~= 1 then
				stage = 1
				actorBase(me, ANIM.pwalk, 0.5)
			end
			mePos = out0:Lerp(out1, t / 4.5)
			actorPlace(me, mePos, out1 + (out1 - out0).Unit * 5)
		elseif t < 7 then
			if stage ~= 2 then
				stage = 2
				actorBase(me, ANIM.pidle, 1)
			end
			mePos = out1
			local a = math.sin((t - 4.5) / 2.5 * math.pi * 2) * 0.9
			actorPlace(me, out1, out1 + Vector3.new(math.sin(a), 0, -math.cos(a)) * 5)
		elseif t < 9.6 then
			if stage ~= 3 then
				stage = 3
				actorBase(me, ANIM.pclimb, 1.4)
			end
			if t < 7.6 then
				mePos = out1:Lerp(crate, (t - 7) / 0.6)
			elseif t < 8.7 then
				mePos = crate:Lerp(sill, (t - 7.6) / 1.1)
			else
				local k = (t - 8.7) / 0.9
				mePos = sill:Lerp(inside, k) + Vector3.new(0, math.sin(k * math.pi) * 0.6, 0)
			end
			actorPlace(me, mePos, win - Vector3.new(0, 0, 10))
		else
			if stage ~= 4 then
				stage = 4
				actorBase(me, ANIM.pidle, 1)
				actorBase(guard, gcfg.walk, 0.45)
			end
			mePos = inside
			actorPlace(me, inside, Vector3.new(4, 0, 63))
			actorWalk(guard, g0, g1, (t - 10) / 5)
		end
	end)
	clearActors()
end

-- INTRO ---------------------------------------------------------------------------------
local function playIntro()
	introPlaying = true
	beginCut()
	black.BackgroundTransparency = 0
	fade(1, 1.5)
	local hq = Vector3.new(0, 30, 0)
	local lines = {
		{ 0.5, "\"We asked for B-00 ALIVE. You brought us a corpse.\" - The letter was one line long. You were fired." },
		{ 6, "No pay. No reference. Just a warning to keep your mouth shut." },
		{ 11, "But you saw the cages. You saw what B-00 used to be. And the files from the zoo safe weren't just money." },
		{ 16, "Tonight you're going back in. Not as their employee." },
		{ 21, "To show the world what Wildcrest really is.", "YOU" },
		{ 26.5, "Wildcrest Headquarters is now closed. Have a pleasant evening.", "BUILDING PA" },
		{ 32, "" },
	}
	local shots = {
		{ 0, 13, function(k) return lerpCF(CFrame.lookAt(Vector3.new(-160, 30, 330), hq), CFrame.lookAt(Vector3.new(-60, 22, 200), hq), k) end },
		{ 13, 25, function(k) local y = 8 + k * 58 return CFrame.lookAt(Vector3.new(40, y, 130), Vector3.new(0, y + 4, 80)) end },
		{ 25, 33, function(k) return lerpCF(CFrame.lookAt(Vector3.new(0, 66, 140), Vector3.new(0, 57, 81)), CFrame.lookAt(Vector3.new(0, 62, 110), Vector3.new(0, 57, 81)), k) end },
		{ 33, 40, function(k) return lerpCF(CFrame.lookAt(Vector3.new(8, 5, 196), Vector3.new(0, 6, 150)), CFrame.lookAt(Vector3.new(4, 5, 186), Vector3.new(0, 10, 80)), k) end },
	}
	task.delay(33, function()
		if introPlaying then
			title.Text = "CHAPTER 3: WILDCREST HQ"
			titleSub.Text = "you're not their employee anymore"
		end
	end)
	local skipped = timeline(40, shots, lines, true)
	title.Text, titleSub.Text = "", ""
	if not skipped then
		local ok, err = pcall(playSneak)
		if not ok then
			warn("Sneak cutscene: " .. tostring(err))
		end
	end
	clearActors()
	if player.Character then
		for _, p in player.Character:GetDescendants() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = 0
			end
		end
	end
	-- you start inside, by the window you climbed through
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		char:PivotTo(CFrame.lookAt(Vector3.new(-14, 3.2, 76.5), Vector3.new(-14, 3.2, 60)))
	end
	introPlaying = false
	endCut()
	notice("They fired you. Now get the evidence and expose Wildcrest.", Color3.fromRGB(255, 210, 120), 6)
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
			introPlaying = false
			endCut()
		end
	end
end)

-- STORY CUTSCENES -----------------------------------------------------------------------
local cutscenes = {}
function cutscenes.sneak() -- (testing: replay the sneak-in)
	playSneak()
	for _, p in (player.Character or Instance.new("Model")):GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 0
		end
	end
end
function cutscenes.release(args)
	local g = args.glass or Vector3.new(90, 6, -50)
	local eye = g + Vector3.new(-6, 1, 26)
	local mcfg = Config.Monsters.Marsh.Anim
	-- Marsh, at his desk in the office, watching it happen on CCTV
	local deskStand, deskLook = Vector3.new(-47, 0, 65.8), Vector3.new(-42.5, 0, 59.5)
	local marsh = makeActor(views:FindFirstChild("Marsh"), deskStand, deskLook)
	actorBase(marsh, mcfg.idle, 1)
	local gestured = false
	task.delay(3.2, function()
		sound(Config.Sounds.Jumpscare, 1.2, 0.6)
	end)
	timeline(12.5, {
		{ 0, 3.2, function(k) return lerpCF(CFrame.lookAt(eye, g), CFrame.lookAt(eye + Vector3.new(2, -1, -10), g), k) end },
		{ 3.2, 4.2, function(k) return CFrame.lookAt(eye + Vector3.new(2, -1, -10), g) * CFrame.new((math.random() - 0.5) * 0.6, (math.random() - 0.5) * 0.6, 0) end },
		{ 4.2, 9, function(k) return lerpCF(CFrame.lookAt(g + Vector3.new(-3, 1, 14), g + Vector3.new(0, -1, -8)), CFrame.lookAt(g + Vector3.new(-1, 0, 8), g + Vector3.new(0, 0, -8)), k) end },
		{ 9, 12.5, function(k)
			local head = deskStand + Vector3.new(0, 4.8, 0)
			local shake = k < 0.25 and CFrame.new((math.random() - 0.5) * 0.25, (math.random() - 0.5) * 0.25, 0) or CFrame.new()
			return lerpCF(CFrame.lookAt(Vector3.new(-41.5, 5.8, 58.5), head), CFrame.lookAt(Vector3.new(-43.6, 5.4, 61.2), head), k) * shake
		end },
	}, {
		{ 0.3, "The last cell lock clicks open. Then the big glass behind it starts to crack..." },
		{ 3.3, "SUBJECT B-01 - CONTAINMENT BREACH", "SYSTEM" },
		{ 5, "It used to be a guest. A visitor on the zoo tour. Wildcrest kept him." },
		{ 9.1, "No. NO. Who opened containment?!", "DIRECTOR MARSH" },
		{ 10.9, "...You. Of course it's you.", "DIRECTOR MARSH" },
	}, false, function(t)
		if t >= 10.9 and not gestured then
			gestured = true
			actorGesture(marsh, ANIM.point, false, 0.9)
		end
	end)
end
function cutscenes.marsh(args)
	local spot = args.pos or Vector3.new(85, 21, -55)
	local mcfg = Config.Monsters.Marsh.Anim
	local walk, camd = openDirs(spot, 14)
	local from = spot + walk.dir * math.clamp(walk.d - 2.5, 2, 9)
	local camPos = spot + camd.dir * math.clamp(camd.d - 1.5, 3.5, 9) + Vector3.new(0, 4.4, 0)
	local marsh = makeActor(views:FindFirstChild("Marsh"), from, spot)
	local stage, pointTrack = 0, nil
	timeline(13, {
		{ 0, 5, function(k) return CFrame.lookAt(camPos, actorHead(marsh, spot + Vector3.new(0, 4.8, 0))) end },
		{ 5, 10.6, function(k)
			local head = actorHead(marsh, spot + Vector3.new(0, 4.8, 0))
			local away = (camPos - head).Unit
			return CFrame.lookAt(head + away * (7 - k * 3), head)
		end },
		{ 10.6, 13, function(k)
			local head = actorHead(marsh, spot + Vector3.new(0, 4.8, 0))
			local away = (camPos - head).Unit
			return CFrame.lookAt(head + away * (4 - k * 1.2) + Vector3.new(0, -0.3, 0), head) * CFrame.new(0, 0, 0)
		end },
	}, {
		{ 0.3, "Well, well. Look who came crawling back.", "DIRECTOR MARSH" },
		{ 5.2, "I fired you for a reason. You couldn't even bring one animal home alive.", "DIRECTOR MARSH" },
		{ 8.3, "And now you've let my best subject out of his cage.", "DIRECTOR MARSH" },
		{ 10.6, "Ha... ha ha. Fine. Let's see how long you last. B-01... fetch.", "DIRECTOR MARSH" },
	}, false, function(t)
		hideReal("Marsh", true)
		if t < 5 then
			if stage ~= 1 then
				stage = 1
				actorBase(marsh, mcfg.walk, 0.55)
			end
			actorWalk(marsh, from, spot, t / 5)
		else
			actorPlace(marsh, spot, Vector3.new(camPos.X, spot.Y, camPos.Z))
			if stage == 1 then
				stage = 2
				actorBase(marsh, mcfg.idle, 1)
			end
			if t >= 5.4 and stage == 2 then
				stage = 3
				pointTrack = actorGesture(marsh, ANIM.point, true, 0.8)
			end
			if t >= 10.6 and stage == 3 then
				stage = 4
				if pointTrack then
					pointTrack:Stop(0.3)
				end
				actorGesture(marsh, ANIM.laugh, true, 1)
			end
		end
	end)
end
function cutscenes.cut(args)
	local c = args.console or Vector3.new(0, 65, -41)
	local mcfg = Config.Monsters.Marsh.Anim
	local stand = c + Vector3.new(4, -2, -4) -- where the server parks the real Marsh (beside the console, by the cable)
	local from = stand + Vector3.new(12, 0, 15)
	local camPos = c + Vector3.new(11, 5, 19)
	local closeCam = c + Vector3.new(7, 2, 4.5)
	local cable = level:FindFirstChild("Roof") and level.Roof:FindFirstChild("Cable")
	local marsh = makeActor(views:FindFirstChild("Marsh"), from, stand)
	local stage, pointTrack = 0, nil
	local function sparks()
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
		p.Size = Vector3.new(1, 1, 1)
		p.Position = c + Vector3.new(0, 1, 0)
		p.Parent = workspace
		local sp = Instance.new("Sparks")
		sp.Parent = p
		local fl = Instance.new("PointLight")
		fl.Color = Color3.fromRGB(140, 200, 255)
		fl.Range = 14
		fl.Brightness = 6
		fl.Parent = p
		task.spawn(function()
			for _ = 1, 14 do
				fl.Enabled = not fl.Enabled
				task.wait(0.07 + math.random() * 0.1)
			end
			fl.Enabled = false
		end)
		game:GetService("Debris"):AddItem(p, 6)
	end
	timeline(15, {
		{ 0, 4, function(k)
			local head = actorHead(marsh, stand + Vector3.new(0, 4.8, 0))
			return CFrame.lookAt(camPos, (head + c) / 2)
		end },
		{ 4, 6.5, function(k)
			return CFrame.lookAt(closeCam, c + Vector3.new(2, -0.5, -3.5)) * CFrame.new((math.random() - 0.5) * 0.15, (math.random() - 0.5) * 0.15, 0)
		end },
		{ 6.5, 11, function(k)
			local head = actorHead(marsh, stand + Vector3.new(0, 4.8, 0))
			local away = (Vector3.new(camPos.X, head.Y, camPos.Z) - head).Unit
			return CFrame.lookAt(head + away * (7.5 - k * 3.5), head)
		end },
		{ 11, 15, function(k)
			local head = actorHead(marsh, stand + Vector3.new(0, 4.8, 0))
			local away = (Vector3.new(camPos.X, head.Y, camPos.Z) - head).Unit
			return lerpCF(CFrame.lookAt(head + away * 4, head), CFrame.lookAt(head + away * 26 + Vector3.new(0, 14, 0), head), k)
		end },
	}, {
		{ 0.2, "Ninety-six percent. So close.", "DIRECTOR MARSH" },
		{ 4.3, "*He rips the uplink cable out. The console sparks and dies.*" },
		{ 6.6, "Do you know how many people tried this before you? I have a cell for each of them.", "DIRECTOR MARSH" },
		{ 9.2, "Nobody will ever see those files.", "DIRECTOR MARSH" },
		{ 11.2, "...B-01. Clean this up.", "DIRECTOR MARSH" },
		{ 13.4, "RUN. The zipline on the south edge of the roof!" },
	}, false, function(t)
		hideReal("Marsh", true)
		if t < 4 then
			if stage ~= 1 then
				stage = 1
				actorBase(marsh, mcfg.walk, 0.7)
			end
			actorWalk(marsh, from, stand, t / 3.6)
		elseif t < 6.5 then
			if stage ~= 2 then
				stage = 2
				actorBase(marsh, mcfg.idle, 1)
				actorPlace(marsh, stand, c)
			end
			if t >= 4.3 and stage == 2 then
				stage = 3
				sparks()
				sound(Config.Sounds.Jumpscare, 0.8, 1.6)
				if cable then
					-- yank: the cable's console end comes up into his hand
					if not cable:GetAttribute("OrigCF") then
						cable:SetAttribute("OrigCF", cable.CFrame)
					end
					local towerEnd = Vector3.new(0, 64.2, -50)
					local hand = stand + Vector3.new(-0.8, 3.2, 1.2)
					cable.Size = Vector3.new(cable.Size.X, cable.Size.Y, (hand - towerEnd).Magnitude)
					cable.CFrame = CFrame.lookAt((hand + towerEnd) / 2, hand)
				end
				actorPlace(marsh, stand + (stand - c).Unit * 0.6, c)
			end
		else
			actorPlace(marsh, marsh and marsh.feet or stand, Vector3.new(camPos.X, 0, camPos.Z))
			if stage < 4 then
				stage = 4
				pointTrack = actorGesture(marsh, ANIM.point, true, 0.8)
			end
			if t >= 11 and stage == 4 then
				stage = 5
				if pointTrack then
					pointTrack:Stop(0.3)
				end
				actorGesture(marsh, ANIM.laugh, true, 1)
			end
		end
	end)
end
function cutscenes.blackout(args)
	local mcfg = Config.Monsters.Marsh.Anim
	local sec = level.Rooms:FindFirstChild("Security")
	local lever = sec and sec:FindFirstChild("BreakerLever")
	local hinge = lever and lever:GetAttribute("Hinge")
	local console, monitors = Vector3.new(15, 0, 22.4), Vector3.new(15, 0, 29)
	local breakerStand = Vector3.new(21.6, 0, 19)
	local marsh = makeActor(views:FindFirstChild("Marsh"), console, monitors)
	local stage = 0
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local you = root and root.Position or Vector3.new(0, 45, 0)
	local youLook = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
	local youCam = you - Vector3.new(youLook.X, 0, youLook.Z).Unit * 7 + Vector3.new(0, 4.5, 0)
	timeline(11, {
		{ 0, 4.5, function(k) return lerpCF(CFrame.lookAt(Vector3.new(21.5, 6.8, 13.5), Vector3.new(15, 4.5, 27)), CFrame.lookAt(Vector3.new(20, 6.2, 15.5), Vector3.new(15, 4.5, 27)), k) end },
		{ 4.5, 6.2, function(k) return CFrame.lookAt(Vector3.new(14, 6, 14), actorHead(marsh, breakerStand + Vector3.new(0, 4.8, 0))) end },
		{ 6.2, 6.9, function(k) return CFrame.lookAt(Vector3.new(20.6, 6, 23.2), Vector3.new(22.8, 5.2, 19)) * CFrame.new((math.random() - 0.5) * 0.1, (math.random() - 0.5) * 0.1, 0) end },
		{ 6.9, 11, function(k) return lerpCF(CFrame.lookAt(youCam, you + Vector3.new(0, 1, 0)), CFrame.lookAt(youCam + Vector3.new(0, 1.5, 0) - Vector3.new(youLook.X, 0, youLook.Z).Unit * 3, you), k) end },
	}, {
		{ 0.3, "Booting MY transmitter? With MY power?", "DIRECTOR MARSH" },
		{ 2.4, "You really think I don't have a switch for that?", "DIRECTOR MARSH" },
		{ 5.2, "Lights out, employee.", "DIRECTOR MARSH" },
		{ 7.2, "*CLUNK* - one by one, every light in the building dies." },
		{ 9.4, "...and something is moving in the vents." },
	}, false, function(t)
		hideReal("Marsh", true)
		if t < 4.5 then
			if stage ~= 1 then
				stage = 1
				actorBase(marsh, mcfg.idle, 1)
			end
		elseif t < 6.2 then
			if stage ~= 2 then
				stage = 2
				actorBase(marsh, mcfg.walk, 0.6)
			end
			actorWalk(marsh, console, breakerStand, (t - 4.5) / 1.5)
		else
			if stage == 2 then
				stage = 3
				actorBase(marsh, mcfg.idle, 1)
				actorPlace(marsh, breakerStand, Vector3.new(30, 0, 19))
				actorGesture(marsh, ANIM.point, false, 1.4)
				if lever and hinge then
					TweenService:Create(lever, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { CFrame = hinge * CFrame.Angles(0, 0, math.rad(150)) * CFrame.new(0, 0.65, 0) }):Play()
				end
				sound(Config.Sounds.Jumpscare, 0.5, 0.45)
			end
			if t >= 6.9 and stage == 3 then
				stage = 4
				setBlackout(true, you)
			end
			if t >= 9.4 and stage == 4 then
				stage = 5
				sound(Config.Sounds.Growl, 1.4, 0.7)
			end
		end
	end)
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
	fade(1, 1.5)
	local road = Vector3.new(0, 4, 240)
	timeline(26, {
		{ 0, 9, function(k) return lerpCF(CFrame.lookAt(Vector3.new(30, 12, 200), Vector3.new(0, 30, 40)), CFrame.lookAt(Vector3.new(10, 8, 260), Vector3.new(0, 40, 40)), k) end },
		{ 9, 17, function(k) return lerpCF(CFrame.lookAt(Vector3.new(0, 70, 120), Vector3.new(0, 60, 80)), CFrame.lookAt(Vector3.new(0, 90, 220), Vector3.new(0, 55, 80)), k) end },
		{ 17, 26, function(k) return CFrame.lookAt(Vector3.new(-80 + k * 10, 50, 300), Vector3.new(0, 40, 0)) end },
	}, {
		{ 0.5, "You made it out of the building alive." },
		{ 4.5, "The files didn't. Wildcrest wiped the uplink before a single byte got out." },
		{ 9.2, "...Wildcrest Corporation today denied rumours of a data leak, calling them 'a hoax by a disgruntled former employee'.", "RADIO" },
		{ 13.5, "Shares rose four percent. In other news, a missing visitor from the Wildcrest Zoo tour has still not been found...", "RADIO" },
		{ 18, "Find the ex-employee. Bring B-01 home. ...And wake up B-02.", "DIRECTOR MARSH (phone)" },
		{ 22.5, "Wildcrest is still out there. And now they're coming for YOU." },
	})
	fade(0, 1)
	task.wait(1)
	title.Text = "TO BE CONTINUED..."
	titleSub.Text = ("CHAPTER 3 - COMPLETE   |   Time %d:%02d   |   %s   |   Secret tapes %d/6"):format(secs // 60, secs % 60, string.upper(difficulty or "Normal"), tapes or 0)
	task.wait(4)
	titleSub.Text = "Chapter 4 is coming...  Returning to the lobby..."
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
		local sec = level.Rooms:FindFirstChild("Security")
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
	local function target()
		local phase = RS:GetAttribute("Phase") or 0
		if phase == 1 then
			if (RS:GetAttribute("Evidence") or 0) >= (RS:GetAttribute("EvidenceNeeded") or 8) then
				return nil
			end
			return nil, nil
		elseif phase == 2 then
			if not RS:GetAttribute("Keycard1") then
				local k = workspace.Items:FindFirstChild("Keycard")
				return k, "GUARD KEYCARD"
			end
			return tagged("CellConsole", function(p) return not p:GetAttribute("Freed") end), "CELL LOCK"
		elseif phase == 3 then
			if not RS:GetAttribute("Keycard2") then
				return tagged("KeypadSafe"), "MARSH'S SAFE"
			end
			return tagged("ServerTerminal"), "UPLOAD TERMINAL"
		elseif phase == 4 then
			if RS:GetAttribute("Blackout") then
				return tagged("GeneratorStation"), "GENERATOR"
			end
			return tagged("TransmitterPanel"), "TRANSMITTER"
		elseif phase == 5 then
			local dish = tagged("DishControl", function(p) local pr = p:FindFirstChildOfClass("ProximityPrompt") return pr and pr.Enabled end)
			if dish then
				return dish, "DISH CONTROL"
			end
			return tagged("BroadcastConsole"), "BROADCAST CONSOLE"
		elseif phase == 6 then
			if RS:GetAttribute("SignalCut") then
				local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if myRoot and myRoot.Position.Y < 30 then
					return workspace.Exterior:FindFirstChild("ExitZone"), "THE GATE"
				end
				return tagged("ZiplineStart"), "ZIPLINE"
			end
		end
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
			local fl = part.Position.Y > 60 and "ROOF" or (part.Position.Y > 40 and "FLOOR 3" or (part.Position.Y > 19 and "FLOOR 2" or "GROUND"))
			txt.Text = ("%s (%s)  %dm"):format(name or "", fl, math.floor(d / 3.5))
			bb.Enabled = d > 8
		end
	end)
end

-- FIRST PERSON: free the mouse whenever something needs clicking (minigames, notes, menus) or M is held/toggled
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
		local v = player:GetAttribute("RunCash") or 0
		cashLabel.Text = v > 0 and ("$%d this run"):format(v) or ""
	end
	player:GetAttributeChangedSignal("RunCash"):Connect(refreshCash)
	refreshCash()
	local senseLabel = label(gui, { Size = UDim2.fromOffset(300, 22), Position = UDim2.new(0, 24, 1, -150), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, TextColor3 = Color3.fromRGB(220, 160, 255), Text = "" })
	local readyAt = 0
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
	RunService.Heartbeat:Connect(function()
		if not player:GetAttribute("Up_Sixth") then
			senseLabel.Text = ""
		elseif os.clock() < readyAt then
			senseLabel.Text = ("SIXTH SENSE [R]: %ds"):format(math.ceil(readyAt - os.clock()))
		else
			senseLabel.Text = "SIXTH SENSE [R]: ready"
		end
	end)
end
