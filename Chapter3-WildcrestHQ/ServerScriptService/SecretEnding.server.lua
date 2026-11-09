-- SECRET ENDING: a strange item is hidden somewhere in this chapter.
-- Pick it up before you win -> a secret cutscene after the normal ending (+$150).
-- Config lives in this script's attributes: Chapter (number), Spot (Vector3).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local CH = script:GetAttribute("Chapter") or 1
local SPOT = script:GetAttribute("Spot") or Vector3.zero

local remote = ReplicatedStorage:FindFirstChild("SecretEnding") or Instance.new("RemoteEvent")
remote.Name = "SecretEnding"
remote.Parent = ReplicatedStorage
local winEvt = ServerStorage:FindFirstChild("SecretWin") or Instance.new("BindableEvent")
winEvt.Name = "SecretWin"
winEvt.Parent = ServerStorage

local STORY = {
	[1] = {
		item = "Torn Transfer Form",
		screen = "WILDCREST ZOO\nSUBJECT TRANSFER LOG",
		final = "DESTINATION: THE ISLAND\nSTATUS: ACTIVE",
		lines = {
			'DIRECTOR: "So they got out with the money. Let them."',
			'DIRECTOR: "The zoo was never the point."',
			'DIRECTOR: "Move the real specimens before anyone asks questions."',
		},
	},
	[2] = {
		item = "Security Tape",
		screen = "MALL CAMERA 07\nRECORDING",
		final = "B-SERIES: 14 SUBJECTS\nSHIPPED TO THE ISLAND",
		lines = {
			'DIRECTOR: "B-00 was only a test."',
			'DIRECTOR: "The zoo, the mall... just places to keep them hidden."',
			'DIRECTOR: "Ship the rest of the B-series to the island. Tonight."',
		},
	},
	[3] = {
		item = "Director's Keycard",
		screen = "HQ BROADCAST\nSIGNAL LOST",
		final = "PROJECT ISLAND\nPHASE 2: READY",
		lines = {
			'DIRECTOR: "So they exposed the HQ. It doesn\'t matter."',
			'DIRECTOR: "The HQ was a front. Everything important is already gone."',
			'DIRECTOR: "Prepare the island. Tell Marsh to bring them to me."',
		},
	},
	[4] = {
		item = "Captain's Logbook",
		screen = "LAST TRAIN\nTRACKING...",
		final = "WELCOME TO THE ISLAND\nCHAPTER 5",
		lines = {
			'DIRECTOR: "They made it onto the last train. Good."',
			'DIRECTOR: "Every line ends at the coast. Every coast ends at the island."',
			'DIRECTOR: "Let them come. It has been waiting for them."',
		},
	},
}
local story = STORY[CH] or STORY[1]

-- The Director's monitoring room, built far away from the map (the secret scene plays here)
local O = Vector3.new(6000, 700, 6000)
local old = workspace:FindFirstChild("SecretRoom")
if old then
	old:Destroy()
end
local room = Instance.new("Model")
room.Name = "SecretRoom"
pcall(function()
	room.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
end)
local function part(name, size, pos, color, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = O + pos
	p.Anchored = true
	p.CanCollide = false
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = room
	return p
end
local rgb = Color3.fromRGB
part("Floor", Vector3.new(40, 1, 40), Vector3.new(0, -0.5, 0), rgb(48, 45, 42), Enum.Material.Concrete)
part("Ceiling", Vector3.new(40, 1, 40), Vector3.new(0, 16.5, 0), rgb(28, 28, 32))
part("WallN", Vector3.new(40, 17, 1), Vector3.new(0, 8, -20.5), rgb(52, 56, 62))
part("WallS", Vector3.new(40, 17, 1), Vector3.new(0, 8, 20.5), rgb(52, 56, 62))
part("WallE", Vector3.new(1, 17, 40), Vector3.new(20.5, 8, 0), rgb(52, 56, 62))
part("WallW", Vector3.new(1, 17, 40), Vector3.new(-20.5, 8, 0), rgb(52, 56, 62))
-- the big screen
local screen = part("Screen", Vector3.new(22, 11, 0.4), Vector3.new(0, 7.5, -19.6), rgb(8, 22, 34))
local sl = Instance.new("SurfaceLight")
sl.Face = Enum.NormalId.Back
sl.Color = rgb(120, 210, 255)
sl.Brightness = 2.5
sl.Range = 24
sl.Angle = 120
sl.Parent = screen
local sg = Instance.new("SurfaceGui")
sg.Name = "Display"
sg.Face = Enum.NormalId.Back
sg.LightInfluence = 0
sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
sg.PixelsPerStud = 40
sg.Parent = screen
local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = rgb(8, 22, 34)
bg.BorderSizePixel = 0
bg.Parent = sg
local txt = Instance.new("TextLabel")
txt.Name = "Text"
txt.Size = UDim2.fromScale(0.9, 0.5)
txt.Position = UDim2.fromScale(0.05, 0.25)
txt.BackgroundTransparency = 1
txt.TextColor3 = rgb(120, 220, 255)
txt.Font = Enum.Font.Code
txt.TextScaled = true
txt.Text = story.screen
txt.Parent = bg
local sea = Instance.new("Frame")
sea.Name = "Island"
sea.Size = UDim2.fromScale(0.5, 0.55)
sea.Position = UDim2.fromScale(0.25, 0.4)
sea.BackgroundColor3 = rgb(10, 45, 80)
sea.BorderSizePixel = 0
sea.Visible = false
sea.Parent = bg
local land = Instance.new("Frame")
land.Size = UDim2.fromScale(0.5, 0.6)
land.Position = UDim2.fromScale(0.25, 0.2)
land.BackgroundColor3 = rgb(40, 110, 60)
land.BorderSizePixel = 0
land.Parent = sea
local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(0.5, 0)
c.Parent = land
local mark = Instance.new("TextLabel")
mark.Size = UDim2.fromScale(0.3, 0.5)
mark.Position = UDim2.fromScale(0.35, 0.25)
mark.BackgroundTransparency = 1
mark.Text = "X"
mark.TextScaled = true
mark.Font = Enum.Font.GothamBlack
mark.TextColor3 = rgb(255, 70, 70)
mark.Parent = land
-- desk, small monitors, files
part("Desk", Vector3.new(10, 0.6, 3.5), Vector3.new(0, 3.2, -11), rgb(62, 42, 28), Enum.Material.Wood)
part("DeskLegL", Vector3.new(0.5, 3, 3), Vector3.new(-4.5, 1.5, -11), rgb(50, 34, 22), Enum.Material.Wood)
part("DeskLegR", Vector3.new(0.5, 3, 3), Vector3.new(4.5, 1.5, -11), rgb(50, 34, 22), Enum.Material.Wood)
for _, x in { -3, 3 } do
	local m = part("Monitor", Vector3.new(2.4, 1.5, 0.2), Vector3.new(x, 4.4, -12.2), rgb(20, 60, 50), Enum.Material.Neon)
	m.Transparency = 0.2
end
part("Folder", Vector3.new(1.4, 0.15, 1), Vector3.new(1, 3.6, -10.5), rgb(150, 120, 70))
part("Cabinet1", Vector3.new(3, 7, 2), Vector3.new(-16, 3.5, -17), rgb(70, 75, 80), Enum.Material.Metal)
part("Cabinet2", Vector3.new(3, 7, 2), Vector3.new(16, 3.5, -17), rgb(70, 75, 80), Enum.Material.Metal)
local crate = part("Crate", Vector3.new(4, 4, 4), Vector3.new(-13, 2, 4), rgb(110, 85, 55), Enum.Material.WoodPlanks)
local cg = Instance.new("SurfaceGui")
cg.Face = Enum.NormalId.Right
cg.Parent = crate
local ct = Instance.new("TextLabel")
ct.Size = UDim2.fromScale(1, 0.5)
ct.Position = UDim2.fromScale(0, 0.25)
ct.BackgroundTransparency = 1
ct.TextScaled = true
ct.Font = Enum.Font.Arcade
ct.TextColor3 = rgb(30, 20, 10)
ct.Text = "SHIP TO: ISLAND"
ct.Parent = cg
-- the Director, back to us, watching the screen
local suit = rgb(28, 28, 32)
part("LegL", Vector3.new(0.9, 3, 0.9), Vector3.new(-0.55, 1.5, -7.5), suit)
part("LegR", Vector3.new(0.9, 3, 0.9), Vector3.new(0.55, 1.5, -7.5), suit)
part("Torso", Vector3.new(2.1, 2.4, 1.1), Vector3.new(0, 4.2, -7.5), suit)
part("ArmL", Vector3.new(0.8, 2.3, 0.9), Vector3.new(-1.5, 4.25, -7.5), suit)
part("ArmR", Vector3.new(0.8, 2.3, 0.9), Vector3.new(1.5, 4.25, -7.5), suit)
part("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 6, -7.5), rgb(205, 170, 140))
part("Hair", Vector3.new(1.26, 0.45, 1.26), Vector3.new(0, 6.5, -7.5), rgb(85, 85, 88))
-- lamp
local lamp = part("Lamp", Vector3.new(3, 0.3, 3), Vector3.new(0, 16, -4), rgb(255, 238, 205), Enum.Material.Neon)
local pl = Instance.new("PointLight")
pl.Color = rgb(255, 225, 185)
pl.Brightness = 1.4
pl.Range = 30
pl.Parent = lamp
room.Parent = workspace

-- The hidden item
local item
local function spawnItem()
	if item then
		item:Destroy()
	end
	item = Instance.new("Part")
	item.Name = "SecretItem"
	item.Size = Vector3.new(1.3, 0.25, 1)
	item.Color = rgb(150, 120, 70)
	item.Anchored = true
	item.CanCollide = false
	item.CFrame = CFrame.new(SPOT + Vector3.new(0, 1.4, 0))
	local l = Instance.new("PointLight")
	l.Color = rgb(190, 150, 255)
	l.Brightness = 0.9
	l.Range = 8
	l.Parent = item
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 4
	pe.Lifetime = NumberRange.new(1, 1.6)
	pe.Speed = NumberRange.new(0.4, 0.8)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.18)
	pe.LightEmission = 1
	pe.Color = ColorSequence.new(rgb(210, 180, 255))
	pe.Parent = item
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Pick up"
	pr.ObjectText = "???"
	pr.HoldDuration = 0.4
	pr.MaxActivationDistance = 8
	pr.RequiresLineOfSight = false
	pr.Parent = item
	local function take(p)
		if workspace:GetAttribute("SecretFound") then
			return
		end
		workspace:SetAttribute("SecretFound", true)
		if item then
			item:Destroy()
			item = nil
		end
		for _, q in Players:GetPlayers() do
			remote:FireClient(q, "found", p and p.DisplayName or "Someone", story.item)
		end
	end
	pr.Triggered:Connect(take)
	if RunService:IsStudio() then
		local d = Instance.new("BindableEvent")
		d.Name = "DebugTrigger"
		d.Parent = pr
		d.Event:Connect(take)
	end
	item.Parent = workspace
end
spawnItem()
task.spawn(function()
	while true do
		task.wait(0.05)
		if item and item.Parent then
			local t = os.clock()
			item.CFrame = CFrame.new(SPOT + Vector3.new(0, 1.4 + math.sin(t * 2) * 0.15, 0)) * CFrame.Angles(0, t * 1.2, 0.25)
		end
	end
end)
-- a new round (resetRound clears SecretFound) puts the item back
workspace:GetAttributeChangedSignal("SecretFound"):Connect(function()
	if not workspace:GetAttribute("SecretFound") and not item then
		spawnItem()
	end
end)

-- the main script fires this from win() when the secret was found
winEvt.Event:Connect(function(list, delaySecs)
	for _, p in list do
		p:SetAttribute("SecretEnding", true)
	end
	task.wait(delaySecs or 6)
	for _, p in list do
		if p.Parent then
			remote:FireClient(p, "play", {
				origin = O,
				lines = story.lines,
				final = story.final,
				chapter = CH,
				reward = 150,
			})
		end
	end
end)
