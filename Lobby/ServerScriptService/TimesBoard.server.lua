-- FASTEST ESCAPES board in the lobby: top 5 times for each chapter (OrderedDataStore "BestTime_ch<N>")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local POS = Vector3.new(-30, 0.4, 10)
local LOOK = Vector3.new(0, 0.4, 34) -- faces the spawn
local NAMES = { "1: CLOSING TIME", "2: LAST CALL", "3: WILDCREST HQ", "4: LAST STOP" }

local old = workspace:FindFirstChild("TimesBoard")
if old then
	old:Destroy()
end
local model = Instance.new("Model")
model.Name = "TimesBoard"
local base = CFrame.lookAt(POS, Vector3.new(LOOK.X, POS.Y, LOOK.Z))
local function part(name, size, cf, color, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = mat or Enum.Material.Metal
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end
part("PostL", Vector3.new(0.6, 13, 0.6), base * CFrame.new(-10.5, 6.5, 0.4), Color3.fromRGB(40, 40, 44))
part("PostR", Vector3.new(0.6, 13, 0.6), base * CFrame.new(10.5, 6.5, 0.4), Color3.fromRGB(40, 40, 44))
local board = part("Board", Vector3.new(21, 10, 0.5), base * CFrame.new(0, 7.8, 0), Color3.fromRGB(14, 14, 18), Enum.Material.SmoothPlastic)
local light = Instance.new("SurfaceLight")
light.Face = Enum.NormalId.Front
light.Color = Color3.fromRGB(255, 200, 120)
light.Brightness = 1.2
light.Range = 14
light.Parent = board
local sg = Instance.new("SurfaceGui")
sg.Face = Enum.NormalId.Front
sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
sg.PixelsPerStud = 40
sg.LightInfluence = 0
sg.Parent = board
local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	for k, v in props do
		l[k] = v
	end
	l.Parent = parent
	return l
end
label(sg, { Size = UDim2.new(1, 0, 0.13, 0), Position = UDim2.fromScale(0, 0.02), Font = Enum.Font.Creepster, TextColor3 = Color3.fromRGB(255, 170, 70), Text = "FASTEST ESCAPES" })
local note = label(sg, { Size = UDim2.new(1, 0, 0.06, 0), Position = UDim2.fromScale(0, 0.92), Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(160, 160, 160),
	Text = "Beat a chapter fast to get on the board!" })
local cols = {}
for i = 1, 4 do
	local col = Instance.new("Frame")
	col.BackgroundColor3 = Color3.fromRGB(28, 26, 30)
	col.BorderSizePixel = 0
	col.Size = UDim2.new(0.23, 0, 0.74, 0)
	col.Position = UDim2.new(0.02 + (i - 1) * 0.245, 0, 0.16, 0)
	col.Parent = sg
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = col
	label(col, { Size = UDim2.new(0.94, 0, 0.13, 0), Position = UDim2.fromScale(0.03, 0.02), TextColor3 = Color3.fromRGB(255, 210, 90), Text = "CHAPTER " .. NAMES[i] })
	local rows = {}
	for r = 1, 5 do
		rows[r] = label(col, { Size = UDim2.new(0.94, 0, 0.14, 0), Position = UDim2.new(0.03, 0, 0.18 + (r - 1) * 0.16, 0), Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left, Text = r .. ". ---" })
	end
	cols[i] = rows
end
model.Parent = workspace

local names = {}
local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = ok and n or ("Player " .. userId)
	return names[userId]
end
local function fmt(secs)
	return ("%d:%02d"):format(secs // 60, secs % 60)
end
local function refresh()
	local anyOk = false
	for i = 1, 4 do
		local ok, page = pcall(function()
			return DataStoreService:GetOrderedDataStore("BestTime_ch" .. i):GetSortedAsync(true, 5):GetCurrentPage()
		end)
		if ok then
			anyOk = true
			for r = 1, 5 do
				local e = page[r]
				local uid = e and tonumber(tostring(e.key):match("%d+"))
				cols[i][r].Text = e and uid and ("%d. %s  %s"):format(r, nameOf(uid), fmt(e.value)) or (r .. ". ---")
			end
		end
	end
	if not anyOk then
		note.Text = RunService:IsStudio() and "(Times show up in the published game)" or "Times are loading..."
	else
		note.Text = "Beat a chapter fast to get on the board!"
	end
end
while true do
	refresh()
	task.wait(120)
end
