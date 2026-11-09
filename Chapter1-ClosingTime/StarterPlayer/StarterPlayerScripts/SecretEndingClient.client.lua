-- SECRET ENDING (client): "you found something" message + the secret cutscene
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("SecretEnding")
local PURPLE = Color3.fromRGB(205, 180, 255)

local function new(cls, parent, props)
	local o = Instance.new(cls)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function tween(o, t, props)
	local tw = TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props)
	tw:Play()
	return tw
end

local function toast(text, secs)
	local gui = new("ScreenGui", player.PlayerGui, { Name = "SecretToast", ResetOnSpawn = false, DisplayOrder = 60, IgnoreGuiInset = true })
	local l = new("TextLabel", gui, { Size = UDim2.new(0.7, 0, 0, 70), Position = UDim2.new(0.15, 0, 0.7, 0), BackgroundTransparency = 1,
		TextColor3 = PURPLE, TextStrokeTransparency = 0.4, Font = Enum.Font.GothamBold, TextScaled = true, TextWrapped = true, Text = text, TextTransparency = 1 })
	new("UITextSizeConstraint", l, { MaxTextSize = 24 })
	tween(l, 0.6, { TextTransparency = 0 })
	task.delay(secs or 6, function()
		tween(l, 1, { TextTransparency = 1 })
		task.wait(1.1)
		gui:Destroy()
	end)
end

local playing = false
local function play(info)
	if playing then
		return
	end
	playing = true
	local O = info.origin
	local cam = workspace.CurrentCamera
	local hidden = {}
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	local gui = new("ScreenGui", player.PlayerGui, { Name = "SecretCutscene", ResetOnSpawn = false, DisplayOrder = 500, IgnoreGuiInset = true })
	local black = new("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5 })
	new("Frame", gui, { Size = UDim2.new(1, 0, 0.11, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 3 })
	new("Frame", gui, { Size = UDim2.new(1, 0, 0.11, 0), Position = UDim2.new(0, 0, 0.89, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 3 })
	local title = new("TextLabel", gui, { Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0.45, -30), BackgroundTransparency = 1, Text = "SECRET ENDING",
		Font = Enum.Font.GothamBlack, TextSize = 46, TextColor3 = PURPLE, ZIndex = 6, TextTransparency = 1 })
	local sub = new("TextLabel", gui, { Size = UDim2.new(0.8, 0, 0.07, 0), Position = UDim2.new(0.1, 0, 0.905, 0), BackgroundTransparency = 1, Text = "",
		Font = Enum.Font.GothamMedium, TextScaled = true, TextColor3 = Color3.fromRGB(240, 235, 225), ZIndex = 4 })
	new("UITextSizeConstraint", sub, { MaxTextSize = 26 })

	tween(title, 0.8, { TextTransparency = 0 })
	task.wait(2)
	tween(title, 0.6, { TextTransparency = 1 })
	task.wait(0.6)

	local oldFov = cam.FieldOfView
	local cur
	-- runs LAST every frame, so no other camera script can move us during the scene
	RunService:BindToRenderStep("SecretCam", Enum.RenderPriority.Last.Value + 5, function()
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 60
		if cur then
			local k = math.clamp((os.clock() - cur.t0) / cur.t, 0, 1)
			k = (1 - math.cos(k * math.pi)) / 2
			cam.CFrame = CFrame.lookAt(O + cur.a:Lerp(cur.b, k), O + cur.look)
		end
	end)
	local function shot(a, b, look, t)
		cur = { a = a, b = b, look = look, t = t, t0 = os.clock() }
	end
	local lines = info.lines or {}
	-- shot 1: wide, the Director watching the screen
	shot(Vector3.new(12, 7, 14), Vector3.new(7, 6, 6), Vector3.new(0, 5, -12), 7.5)
	tween(black, 1.2, { BackgroundTransparency = 1 })
	task.wait(1)
	sub.Text = lines[1] or ""
	task.wait(3.2)
	sub.Text = lines[2] or ""
	task.wait(3.3)
	-- shot 2: over his shoulder
	shot(Vector3.new(2.6, 6.8, -2), Vector3.new(1.6, 6.6, -4), Vector3.new(0, 7.2, -19), 7)
	sub.Text = lines[3] or ""
	task.wait(3.5)
	local room = workspace:FindFirstChild("SecretRoom")
	local disp = room and room:FindFirstChild("Screen") and room.Screen:FindFirstChild("Display")
	if disp then
		local frame = disp:FindFirstChildOfClass("Frame")
		if frame then
			if frame:FindFirstChild("Text") then
				frame.Text.Position = UDim2.fromScale(0.05, 0.04)
				frame.Text.Size = UDim2.fromScale(0.9, 0.32)
				frame.Text.Text = info.final or ""
				frame.Text.TextColor3 = Color3.fromRGB(255, 120, 120)
			end
			if frame:FindFirstChild("Island") then
				frame.Island.Visible = true
			end
		end
	end
	sub.Text = ""
	task.wait(3.5)
	-- shot 3: push in on the screen
	shot(Vector3.new(0, 7.5, -7), Vector3.new(0, 7.5, -11.5), Vector3.new(0, 7.5, -19.6), 5)
	sub.Text = ("SECRET ENDING %d FOUND!  +$%d"):format(info.chapter or 0, info.reward or 0)
	sub.TextColor3 = PURPLE
	task.wait(4.5)
	tween(black, 1, { BackgroundTransparency = 0 })
	task.wait(1.2)
	RunService:UnbindFromRenderStep("SecretCam")
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = oldFov
	for _, g in hidden do
		if g.Parent then
			g.Enabled = true
		end
	end
	gui:Destroy()
	playing = false
end

remote.OnClientEvent:Connect(function(kind, a, b)
	if kind == "found" then
		toast(("%s found the %s...\nSomething about this feels important. Win the chapter to see what it means."):format(a or "Someone", b or "???"), 7)
	elseif kind == "play" then
		play(a or {})
	end
end)
