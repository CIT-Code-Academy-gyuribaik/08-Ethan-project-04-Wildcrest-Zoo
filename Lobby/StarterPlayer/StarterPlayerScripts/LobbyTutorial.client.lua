-- Lobby: "How to play" guide (opens by itself for new players) + animated START HERE guide
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local PAGES = {
	{ "WELCOME TO CLOSING TIME", "A horror game told in chapters.\n\nYou work for Wildcrest Corp - the company that runs the zoo. Tonight you'll find out what they've really been hiding... and they'll do anything to keep it secret." },
	{ "HOW TO START", "Follow the glowing yellow path to the van marked START HERE.\n\nStep into the area BEHIND the van. When the countdown ends, the van drives everyone waiting there into CHAPTER 1.\n\nPlay with friends: wait behind the same van!" },
	{ "IN A CHAPTER", "Your goal is always written at the TOP-LEFT of the screen, and a yellow MARKER points the way (press H to hide/show it).\n\nMonsters and guards hunt you. HIDE in closets and lockers, use your flashlight, and don't make noise. If you lose all your lives, you're sent back here." },
	{ "CONTROLS", "WASD - walk        Mouse - look around\nSHIFT - sprint (watch your stamina)\nF - flashlight\nE - hide / come out of a hiding spot\nQ - stun gun (when you have one)\nM - free your mouse to click things\nH - show / hide the objective marker" },
	{ "CASH & THE SHOP", "Every chapter pays CASH: grab the green cash bundles and get a bonus for escaping.\n\nSpend it at the green SHOP stall here in the lobby: brighter flashlights, beam colours, outfits, skills like Sixth Sense - and Spare Lives for hard chapters." },
	{ "UNLOCK THE STORY", "Beat a chapter to unlock the next van.\n\nChapter 1: Closing Time (the zoo)\nChapter 2: Last Call (the mall)\nChapter 3: Wildcrest HQ\nChapter 4: Last Stop (the subway)\n\nGood luck, employee." },
}

local gui = Instance.new("ScreenGui")
gui.Name = "HowToPlay"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")
local function new(cls, parent, props)
	local o = Instance.new(cls)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local dim = new("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false })
local card = new("Frame", dim, { Size = UDim2.fromOffset(580, 380), Position = UDim2.new(0.5, -290, 0.5, -190), BackgroundColor3 = Color3.fromRGB(20, 20, 24) })
new("UICorner", card, { CornerRadius = UDim.new(0, 14) })
new("UIStroke", card, { Color = Color3.fromRGB(255, 220, 80), Thickness = 2 })
local title = new("TextLabel", card, { Size = UDim2.new(1, -40, 0, 50), Position = UDim2.fromOffset(20, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 30,
	TextColor3 = Color3.fromRGB(255, 220, 80), TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
local body = new("TextLabel", card, { Size = UDim2.new(1, -40, 1, -150), Position = UDim2.fromOffset(20, 72), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 19, TextWrapped = true,
	TextColor3 = Color3.fromRGB(235, 235, 230), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "" })
local pageLbl = new("TextLabel", card, { Size = UDim2.fromOffset(120, 30), Position = UDim2.new(0, 20, 1, -54), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16,
	TextColor3 = Color3.fromRGB(150, 150, 150), TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
local function button(text, x, color)
	local b = new("TextButton", card, { Size = UDim2.fromOffset(130, 42), Position = UDim2.new(1, x, 1, -62), BackgroundColor3 = color, Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), Text = text })
	new("UICorner", b, { CornerRadius = UDim.new(0, 8) })
	return b
end
local back = button("BACK", -300, Color3.fromRGB(60, 60, 70))
local nextB = button("NEXT", -155, Color3.fromRGB(40, 130, 60))
local skip = new("TextButton", card, { Size = UDim2.fromOffset(90, 26), Position = UDim2.new(1, -110, 0, 22), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Color3.fromRGB(170, 170, 170), Text = "Skip >>" })
local page = 1
local function show()
	title.Text = PAGES[page][1]
	body.Text = PAGES[page][2]
	pageLbl.Text = ("%d / %d"):format(page, #PAGES)
	back.Visible = page > 1
	nextB.Text = page == #PAGES and "LET'S GO!" or "NEXT"
end
local function setOpen(on)
	dim.Visible = on
	player:SetAttribute("TutorialOpen", on)
	if on then
		page = 1
		show()
	end
end
nextB.MouseButton1Click:Connect(function()
	if page < #PAGES then
		page += 1
		show()
	else
		setOpen(false)
	end
end)
back.MouseButton1Click:Connect(function()
	page = math.max(1, page - 1)
	show()
end)
skip.MouseButton1Click:Connect(function()
	setOpen(false)
end)
-- always-there button
local help = new("TextButton", gui, { Size = UDim2.fromOffset(150, 36), Position = UDim2.new(0, 16, 0, 64), BackgroundColor3 = Color3.fromRGB(40, 35, 15), BackgroundTransparency = 0.15,
	Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Color3.fromRGB(255, 220, 80), Text = "HOW TO PLAY" })
new("UICorner", help, { CornerRadius = UDim.new(0, 8) })
help.MouseButton1Click:Connect(function()
	setOpen(not dim.Visible)
end)
-- free the mouse while the guide is open (the lobby is first person)
RunService:BindToRenderStep("TutorialMouse", Enum.RenderPriority.Camera.Value + 11, function()
	if dim.Visible then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end)
-- first time? open it after the title card
task.spawn(function()
	local t0 = os.clock()
	while player:GetAttribute("FirstTime") == nil and os.clock() - t0 < 15 do
		task.wait(0.5)
	end
	if player:GetAttribute("FirstTime") then
		task.wait(4)
		setOpen(true)
	end
end)
-- animate the START HERE guide
local guide = workspace:WaitForChild("Lobby"):WaitForChild("Guide", 20)
if guide then
	local arrow = guide:FindFirstChild("BobArrow")
	local home = arrow and arrow.CFrame
	local dots = {}
	for _, d in guide:GetChildren() do
		if d.Name == "PathDot" then
			table.insert(dots, d)
		end
	end
	table.sort(dots, function(a, b)
		return a.Position.Z > b.Position.Z
	end)
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		if arrow and home then
			arrow.CFrame = home + Vector3.new(0, math.sin(t * 3) * 0.8, 0)
		end
		for k, d in dots do
			d.Transparency = 0.15 + 0.6 * (0.5 + 0.5 * math.sin(t * 4 - k * 0.6))
		end
		-- hide the path once you've beaten chapter 1
		local beaten = player:GetAttribute("Ch2Unlocked") == true
		for _, d in dots do
			d.LocalTransparencyModifier = beaten and 1 or 0
		end
	end)
end
