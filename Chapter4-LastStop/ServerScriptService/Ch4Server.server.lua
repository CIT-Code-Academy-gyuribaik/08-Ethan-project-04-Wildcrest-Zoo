-- CHAPTER 4: LAST STOP - server (framework from chapter 3)
-- Expose Wildcrest: collect evidence, free the test subjects (releases B-01), upload the files,
-- boot the transmitter, align the dish and broadcast from the roof... then escape by zipline.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("HQConfig"))
local PlaceIds = require(ReplicatedStorage:WaitForChild("PlaceIds"))
local level = workspace:WaitForChild("Tower")
local exterior = workspace:WaitForChild("City")
local start = level:WaitForChild("Markers"):WaitForChild("Start")
local exitZone = exterior:WaitForChild("ExitZone")

local monstersFolder = Instance.new("Folder")
monstersFolder.Name = "Monsters"
monstersFolder.Parent = workspace
local itemsFolder = Instance.new("Folder")
itemsFolder.Name = "Items"
itemsFolder.Parent = workspace

local remotes = Instance.new("Folder")
remotes.Name = "HQRemotes"
remotes.Parent = ReplicatedStorage
local function remote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local Notify = remote("Notify")
local Caught = remote("Caught")
local ShowNote = remote("ShowNote")
local MinigameRemote = remote("Minigame")
local MinigameResult = remote("MinigameResult")
local StunRemote = remote("Stun")
local LeaveHide = remote("LeaveHide")
local StateRemote = remote("State")
local ChooseDifficulty = remote("ChooseDifficulty")
local CutsceneRemote = remote("Cutscene")
local PARemote = remote("PA")
local Ending = remote("Ending")
local VentRemote = remote("Vent")
local ZipRemote = remote("Zip")
local AdminRemote = remote("Admin")

local roster = {} -- [player] = { lives, hidden, protectedUntil, sprinting, flashlight, ... }
local savedLives = {}
local monsters = {}
local round = { active = false, phase = 0, id = 0 }

local function D()
	return Config.Difficulties[round.difficulty or "Normal"] or Config.Difficulties.Normal
end
local function setObjective(text)
	ReplicatedStorage:SetAttribute("Objective", text)
end
local function setPhase(p)
	round.phase = p
	ReplicatedStorage:SetAttribute("Phase", p)
end
local function inGamePlayers()
	local list = {}
	for p in roster do
		if p.Parent then
			table.insert(list, p)
		end
	end
	return list
end
local function notifyAll(text, color)
	for _, p in inGamePlayers() do
		Notify:FireClient(p, text, color)
	end
end
local function pa(line, who)
	for _, p in Players:GetPlayers() do
		PARemote:FireClient(p, line, who or "MARSH")
	end
end
local function charParts(player)
	local char = player.Character
	if not char then
		return nil
	end
	return char, char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("Head")
end
local function prompt(parent, action, object, hold, distance)
	local old = parent:FindFirstChildOfClass("ProximityPrompt")
	if old then
		old:Destroy()
	end
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = action
	pr.ObjectText = object or ""
	pr.HoldDuration = hold or 0
	pr.MaxActivationDistance = distance or 9
	pr.RequiresLineOfSight = false
	pr.Parent = parent
	return pr
end
-- every prompt handler goes through here (in Studio, tests can fire it through a BindableEvent)
local function onTrigger(pr, fn)
	pr.Triggered:Connect(fn)
	if RunService:IsStudio() then
		local be = Instance.new("BindableEvent")
		be.Name = "DebugTrigger"
		be.Parent = pr
		be.Event:Connect(fn)
	end
end
local function marks(tag)
	local list = {}
	for _, m in CollectionService:GetTagged(tag) do
		if m:IsDescendantOf(level) or m:IsDescendantOf(exterior) then
			table.insert(list, m)
		end
	end
	return list
end
local function floorOf(y)
	if y < -150 then
		return 25 -- the last train (ride set)
	elseif y < -45 then
		return 23 -- sewers
	elseif y < -32 then
		return 22 -- track level / the dark tunnel
	elseif y < -22 then
		return 21 -- subway platform level
	elseif y < -6 then
		return 20 -- subway ticket hall
	end
	return math.clamp(math.floor((y + 3) / 14) + 1, 1, 13) -- tower floors (14 studs each)
end
local function rayParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { monstersFolder, itemsFolder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end
local function itemPart(name, size, color, cf, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	if shape then
		p.Shape = shape
	end
	p.CFrame = cf
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 7
	l.Brightness = 1
	l.Parent = p
	p.Parent = itemsFolder
	return p
end
local function sound(id, parent, volume, pitch)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 1
	s.PlaybackSpeed = pitch or 1
	s.RollOffMaxDistance = 120
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 8)
	return s
end

-- KEYCARD DOORS: open for anyone who swiped once (team keycard), and briefly for hunters
local doorState = {}
local function setDoor(door, open)
	local st = doorState[door]
	if not st then
		st = { home = door.CFrame, open = false }
		doorState[door] = st
	end
	if st.open == open then
		return
	end
	st.open = open
	door.CanCollide = not open
	TweenService:Create(door, TweenInfo.new(0.6), { CFrame = open and st.home * CFrame.new(0, 9.5, 0) or st.home }):Play()
end
for _, d in CollectionService:GetTagged("KeycardDoor") do
	setDoor(d, false)
end
local function doorByName(name)
	for _, d in CollectionService:GetTagged("KeycardDoor") do
		if d.Name == name then
			return d
		end
	end
end

-- MONSTERS ---------------------------------------------------------------------------
local patrolByFloor = setmetatable({}, { __index = function(t, k) local v = {} rawset(t, k, v) return v end })
for _, m in marks("PatrolPoint") do
	table.insert(patrolByFloor[floorOf(m.Position.Y)], m.Position)
end
for _, m in marks("RoofPoint") do
	table.insert(patrolByFloor[4], m.Position)
end
local vents = marks("VentPoint")
local hideSpots = {}
for _, h in level.HidingSpots:GetChildren() do
	table.insert(hideSpots, h)
end

local function loadAnims(m)
	if m.model:GetAttribute("BoneRig") then
		-- skinned creature: the clients animate its bones themselves
		m.tracks = {}
		m.anim = nil
		return
	end
	local animator = m.model.Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", m.model.Humanoid)
	m.tracks = {}
	for k, id in m.cfg.Anim do
		local a = Instance.new("Animation")
		a.AnimationId = "rbxassetid://" .. id
		local ok, tr = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if ok then
			tr.Looped = true
			m.tracks[k] = tr
		end
	end
	m.anim = nil
end
local function playAnim(m, name, speed)
	if not m.tracks then
		return
	end
	local tr = m.tracks[name]
	if m.anim ~= name then
		for k, t in m.tracks do
			if k ~= name and t.IsPlaying then
				t:Stop(0.2)
			end
		end
		if tr then
			tr:Play(0.2)
		end
		m.anim = name
	end
	if tr and speed then
		tr:AdjustSpeed(speed)
	end
end

local function spawnMonster(kind, cframe, homeFloor)
	local model = ServerStorage.Monsters:FindFirstChild(kind):Clone()
	local hip = model:GetAttribute("HipHeight") or 3
	local base = Config.Monsters[kind]
	local d = D()
	local cfg = table.clone(base)
	cfg.PatrolSpeed = base.PatrolSpeed * d.Speed
	cfg.ChaseSpeed = base.ChaseSpeed * d.Speed
	cfg.Sight = base.Sight * d.Senses
	cfg.SightFlashlight = base.SightFlashlight * d.Senses
	cfg.Hearing = base.Hearing * d.Senses
	model:PivotTo(cframe + Vector3.new(0, hip, 0))
	model.Parent = monstersFolder
	local m = {
		kind = kind, cfg = cfg, model = model, root = model.PrimaryPart, hip = hip, home = homeFloor or floorOf(cframe.Position.Y),
		state = "Patrol", waypoints = nil, wpIndex = 1, target = nil, lastSeenPos = nil, lastSeenTime = 0,
		idleUntil = os.clock() + 2, repathAt = 0, pathing = false, yaw = 0, feetPos = cframe.Position, lastMoveAt = os.clock(),
		path = PathfindingService:CreatePath({ AgentRadius = cfg.AgentRadius, AgentHeight = cfg.AgentHeight, AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 4 }),
	}
	loadAnims(m)
	playAnim(m, "idle")
	local s = Instance.new("Sound")
	s.Name = "Growl"
	s.SoundId = (kind == "B01" or kind == "Thing") and Config.Sounds.Growl or ""
	s.Volume = 2
	s.PlaybackSpeed = 0.8
	s.RollOffMaxDistance = 110
	s.Parent = m.root
	m.growl = (kind == "B01" or kind == "Thing") and s or nil
	m.nextGrowl = os.clock() + 6
	table.insert(monsters, m)
	return m
end
local function clearMonsters()
	for _, m in monsters do
		if m.model then
			m.model:Destroy()
		end
	end
	table.clear(monsters)
end
local function monsterOf(kind)
	for _, m in monsters do
		if m.kind == kind and not m.dead then
			return m
		end
	end
end

local function computePath(m, goal)
	if m.pathing then
		return
	end
	m.pathing = true
	task.spawn(function()
		local ok = pcall(function()
			m.path:ComputeAsync(m.feetPos + Vector3.new(0, 1, 0), goal + Vector3.new(0, 1, 0))
		end)
		m.pathing = false
		if not m.model.Parent then
			return
		end
		if ok and m.path.Status == Enum.PathStatus.Success then
			local wps = {}
			for _, w in m.path:GetWaypoints() do
				table.insert(wps, w.Position)
			end
			m.waypoints = wps
			m.wpIndex = math.min(2, #wps)
		else
			m.waypoints = nil
			m.failedAt = os.clock()
			if m.state == "Patrol" then
				m.badGoals = m.badGoals or {}
				m.badGoals[goal] = true
			end
		end
	end)
end
local function pickPatrol(m)
	local list
	if m.kind == "Guard" then
		list = patrolByFloor[m.home]
	else
		-- the hunters follow the players' floors
		local floors = {}
		for _, p in inGamePlayers() do
			local _, r = charParts(p)
			if r then
				floors[floorOf(r.Position.Y)] = true
			end
		end
		local options = {}
		for f in floors do
			for _, pt in patrolByFloor[f] do
				table.insert(options, pt)
			end
		end
		list = #options > 0 and options or patrolByFloor[floorOf(m.feetPos.Y)]
	end
	if not list or #list == 0 then
		return
	end
	local goal
	for _ = 1, 6 do
		goal = list[math.random(#list)]
		if (goal - m.feetPos).Magnitude > 16 and not (m.badGoals and m.badGoals[goal]) then
			break
		end
	end
	computePath(m, goal)
end
local function hasLOS(a, b)
	return workspace:Raycast(a, b - a, rayParams()) == nil
end
local function eyePos(m)
	return m.root.Position + Vector3.new(0, 1.6, 0)
end
local function perceive(m, player, st)
	if player:GetAttribute("AdminGod") or st.hidden or os.clock() < (st.protectedUntil or 0) or st.zipping then
		return nil
	end
	local _, root, _, head = charParts(player)
	if not root then
		return nil
	end
	local cfg = m.cfg
	local to = (head or root).Position - eyePos(m)
	local dist = to.Magnitude
	if math.abs(root.Position.Y - m.feetPos.Y) > 9 then
		return nil -- a different floor
	end
	if dist < cfg.Sense then
		return "see"
	end
	local range = st.flashlight and cfg.SightFlashlight or cfg.Sight
	if dist < range then
		local look = m.root.CFrame.LookVector
		local flatTo = Vector3.new(to.X, 0, to.Z)
		if flatTo.Magnitude > 0 and look:Dot(flatTo.Unit) > math.cos(math.rad(cfg.FOV / 2)) and hasLOS(eyePos(m), (head or root).Position) then
			return "see"
		end
	end
	local ears = player:GetAttribute("Up_Silent") and 0.65 or 1
	if st.sprinting and dist < cfg.Hearing * ears then
		return "hear"
	end
	if st.moving and dist < cfg.Hearing * 0.35 * ears then
		return "hear"
	end
	return nil
end
local catchPlayer -- (defined below)
local unhide

-- B-01 crawls through the vents to come out near someone
local function ventTravel(m, targetPlayer)
	local _, r = charParts(targetPlayer)
	if not r or #vents < 2 then
		return
	end
	local pf = floorOf(r.Position.Y)
	local best, bd
	for _, v in vents do
		if floorOf(v.Position.Y) == pf then
			local d = (v.Position - r.Position).Magnitude
			if d > 22 and (not bd or d < bd) then
				best, bd = v, d
			end
		end
	end
	if not best then
		return
	end
	m.inVent = true
	m.waypoints = nil
	local fromPos = m.feetPos
	for _, p in inGamePlayers() do
		VentRemote:FireClient(p, fromPos, "in")
	end
	m.model:PivotTo(CFrame.new(0, -500, 0))
	m.feetPos = Vector3.new(0, -500, 0)
	local id = round.id
	task.delay(4, function()
		if round.id ~= id or not m.model.Parent then
			return
		end
		m.feetPos = Vector3.new(best.Position.X, best.Position.Y - 3, best.Position.Z)
		m.inVent = false
		m.state = "Search"
		m.lastSeenPos = r.Position
		m.searchUntil = os.clock() + 10
		m.lastMoveAt = os.clock()
		for _, p in inGamePlayers() do
			VentRemote:FireClient(p, best.Position, "out")
		end
		if m.growl then
			m.growl:Play()
		end
	end)
end

local function think(m)
	if ReplicatedStorage:GetAttribute("AdminFreeze") or m.dead or m.inVent or os.clock() < (round.cutsceneUntil or 0) then
		return
	end
	if os.clock() < (m.stunnedUntil or 0) then
		m.lastMoveAt = os.clock()
		return
	end
	-- watchdog: should be moving but isn't -> fresh start
	if os.clock() - m.lastMoveAt > 12 and os.clock() > (m.idleUntil or 0) then
		m.lastMoveAt = os.clock()
		m.pathing = false
		m.waypoints = nil
		m.badGoals = nil
		m.state = "Patrol"
		m.target = nil
		m.model:SetAttribute("Chasing", nil)
	end
	local bestSeen, bestDist, heardPos = nil, math.huge, nil
	for _, player in inGamePlayers() do
		local st = roster[player]
		local sense = perceive(m, player, st)
		local _, root = charParts(player)
		if sense and root then
			local d = (root.Position - m.root.Position).Magnitude
			if sense == "see" and d < bestDist then
				bestSeen, bestDist = player, d
				m.lastRealSeen = os.clock()
			elseif sense == "hear" then
				heardPos = root.Position
			end
		end
	end
	-- forced hunts (scripted chases): the hunter just knows where its target is
	if m.huntUntil and os.clock() < m.huntUntil and m.huntTarget and roster[m.huntTarget] and not roster[m.huntTarget].hidden then
		bestSeen = m.huntTarget
	end
	-- B-01 tears apart any guard it reaches
	if m.kind == "B01" or m.kind == "Thing" then
		for _, g in monsters do
			if g.kind == "Guard" and not g.dead and (g.feetPos - m.feetPos).Magnitude < 5.5 then
				g.dead = true
				sound(Config.Sounds.Jumpscare, g.root, 1.4, 0.7)
				notifyAll("A guard's scream echoes through the building... then silence.", Color3.fromRGB(255, 90, 80))
				local gm = g.model
				task.delay(0.4, function()
					if gm then
						gm:Destroy()
					end
				end)
			end
		end
		if m.growl and os.clock() > m.nextGrowl then
			m.growl:Play()
			m.nextGrowl = os.clock() + math.random(7, 14)
		end
	end
	if bestSeen then
		local _, root = charParts(bestSeen)
		if m.state ~= "Chase" then
			m.model:SetAttribute("Chasing", bestSeen.Name)
			if m.kind == "Guard" then
				Notify:FireClient(bestSeen, "\"HEY! STOP RIGHT THERE!\"", Color3.fromRGB(120, 180, 255))
			end
		end
		m.state = "Chase"
		m.target = bestSeen
		m.lastSeenPos = root.Position
		m.lastSeenTime = os.clock()
	elseif m.state == "Chase" then
		local st = m.target and roster[m.target]
		if st and st.hidden and os.clock() - (m.lastRealSeen or 0) < 2.5 and m.kind ~= "Guard" then
			-- it saw you get in there
			m.state = "Hunt"
			m.huntHidden = st.hidden
		elseif os.clock() - m.lastSeenTime > 4 then
			m.state = "Search"
			m.searchUntil = os.clock() + 8
			m.model:SetAttribute("Chasing", nil)
			computePath(m, m.lastSeenPos)
		end
	elseif heardPos and m.state ~= "Hunt" then
		m.state = "Search"
		m.lastSeenPos = heardPos
		m.searchUntil = os.clock() + 8
		computePath(m, heardPos)
	end

	if m.state == "Chase" and m.target then
		local _, root = charParts(m.target)
		if not root or not roster[m.target] then
			m.state = "Search"
			m.searchUntil = os.clock() + 5
			return
		end
		local flat = Vector3.new(root.Position.X - m.feetPos.X, 0, root.Position.Z - m.feetPos.Z)
		if flat.Magnitude < m.cfg.CatchRange and math.abs(root.Position.Y - 3 - m.feetPos.Y) < 5 then
			catchPlayer(m, m.target)
			return
		end
		if flat.Magnitude < 26 and math.abs(root.Position.Y - 3 - m.feetPos.Y) < 3 and hasLOS(eyePos(m), root.Position) then
			m.waypoints = { Vector3.new(root.Position.X, m.feetPos.Y, root.Position.Z) }
			m.wpIndex = 1
		elseif os.clock() > m.repathAt then
			m.repathAt = os.clock() + 0.5
			computePath(m, root.Position - Vector3.new(0, 3, 0))
		end
	elseif m.state == "Hunt" then
		local spot = m.huntHidden
		if not spot or not spot:GetAttribute("Occupant") then
			m.state = "Search"
			m.searchUntil = os.clock() + 6
			return
		end
		local front = spot.Door.Position + (spot.Door.Position - spot.Inside.Position).Unit * 2
		local flat = Vector3.new(front.X - m.feetPos.X, 0, front.Z - m.feetPos.Z)
		if flat.Magnitude < m.cfg.CatchRange + 1.5 then
			local victim = Players:FindFirstChild(spot:GetAttribute("Occupant"))
			if victim then
				unhide(victim, true)
				catchPlayer(m, victim)
			end
			m.state = "Patrol"
		elseif os.clock() > m.repathAt then
			m.repathAt = os.clock() + 0.6
			computePath(m, Vector3.new(front.X, m.feetPos.Y, front.Z))
		end
	elseif m.state == "Search" then
		if os.clock() > (m.searchUntil or 0) then
			m.state = "Patrol"
			m.waypoints = nil
		elseif not m.waypoints and not m.pathing then
			computePath(m, (m.lastSeenPos or m.feetPos) + Vector3.new(math.random(-12, 12), 0, math.random(-12, 12)))
		end
	elseif m.state == "Patrol" then
		-- B-01 is smart: when it has lost everyone for a while it takes the vents
		if m.kind == "B01" and os.clock() - m.lastSeenTime > 14 and os.clock() > (m.nextVent or 0) then
			m.nextVent = os.clock() + 22
			local list = inGamePlayers()
			if #list > 0 then
				ventTravel(m, list[math.random(#list)])
				return
			end
		end
		-- Marsh radios in: he always learns roughly where someone is
		if m.kind == "Marsh" and os.clock() > (m.nextIntel or 0) then
			m.nextIntel = os.clock() + 18
			local list = inGamePlayers()
			if #list > 0 then
				local _, r = charParts(list[math.random(#list)])
				if r then
					m.state = "Search"
					m.lastSeenPos = r.Position + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
					m.searchUntil = os.clock() + 12
					computePath(m, m.lastSeenPos - Vector3.new(0, 3, 0))
					pa(({ "Cameras have you on floor " .. floorOf(r.Position.Y) .. ". I'm coming.", "Security, sweep floor " .. floorOf(r.Position.Y) .. ". Now.", "You can't hide from me in my own building." })[math.random(3)])
					return
				end
			end
		end
		-- the smart one peeks into hiding spots as it passes
		if m.kind ~= "Guard" and os.clock() > (m.nextPeek or 0) then
			m.nextPeek = os.clock() + 3
			for _, spot in hideSpots do
				if spot:GetAttribute("Occupant") and (spot.Inside.Position - m.root.Position).Magnitude < 14 and math.random() < 0.3 then
					m.state = "Hunt"
					m.huntHidden = spot
					return
				end
			end
		end
		if not m.waypoints and not m.pathing and os.clock() > m.idleUntil and os.clock() > (m.failedAt or 0) + 2 then
			pickPatrol(m)
		end
	end
end

local function step(m, dt)
	if ReplicatedStorage:GetAttribute("AdminFreeze") or m.dead or m.inVent or os.clock() < (round.cutsceneUntil or 0) then
		if m.tracks then
			playAnim(m, "idle")
		end
		return
	end
	if os.clock() < (m.stunnedUntil or 0) then
		playAnim(m, "idle", 0.2)
		m.root.CFrame = CFrame.new(m.feetPos + Vector3.new(0, m.hip, 0)) * CFrame.Angles(0, m.yaw, 0) * CFrame.Angles((math.random() - 0.5) * 0.1, 0, (math.random() - 0.5) * 0.1)
		return
	end
	local speed = (m.state == "Chase" or m.state == "Hunt") and m.cfg.ChaseSpeed or m.cfg.PatrolSpeed
	if m.huntUntil and os.clock() < m.huntUntil then
		speed *= 0.92
	end
	local moving = false
	if m.waypoints then
		local wp = m.waypoints[m.wpIndex]
		if wp then
			local here = m.feetPos
			local flat = Vector3.new(wp.X - here.X, 0, wp.Z - here.Z)
			local d = flat.Magnitude
			if d < 1 then
				m.wpIndex += 1
				if m.wpIndex > #m.waypoints then
					m.waypoints = nil
					if m.state == "Patrol" then
						m.idleUntil = os.clock() + math.random(1, 3)
					end
				end
			else
				local dir = flat.Unit
				local nf = here + dir * math.min(d, speed * dt)
				local ny = here.Y + math.clamp(wp.Y - here.Y, -speed * dt, speed * dt)
				m.feetPos = Vector3.new(nf.X, ny, nf.Z)
				local targetYaw = math.atan2(-dir.X, -dir.Z)
				local diff = (targetYaw - m.yaw + math.pi) % (2 * math.pi) - math.pi
				m.yaw += diff * math.min(1, dt * 10)
				moving = true
			end
		else
			m.waypoints = nil
		end
	end
	if moving then
		m.lastMoveAt = os.clock()
		if speed > m.cfg.PatrolSpeed + 1 then
			playAnim(m, "run", speed / 16)
		else
			playAnim(m, "walk", speed / 9)
		end
	else
		playAnim(m, "idle", 1)
	end
	m.root.CFrame = CFrame.new(m.feetPos + Vector3.new(0, m.hip, 0)) * CFrame.Angles(0, m.yaw, 0)
	-- doors open for the hunters
	for door, st in doorState do
		if not st.open and (door.Position - m.root.Position).Magnitude < 8 then
			setDoor(door, true)
			local id = round.id
			task.delay(3, function()
				if round.id == id and not round.unlocked[door.Name] then
					setDoor(door, false)
				end
			end)
		end
	end
end

task.spawn(function()
	local acc = 0
	while true do
		local dt = RunService.Heartbeat:Wait()
		acc += dt
		local doThink = acc > 0.2
		if doThink then
			acc = 0
		end
		for _, m in table.clone(monsters) do
			if m.model.Parent then
				if doThink then
					local ok, err = pcall(think, m)
					if not ok then
						warn("think: " .. tostring(err))
					end
				end
				local ok, err = pcall(step, m, dt)
				if not ok then
					warn("step: " .. tostring(err))
				end
			end
		end
	end
end)

-- HIDING ------------------------------------------------------------------------------
local function hide(player, spot)
	local st = roster[player]
	local _, root = charParts(player)
	if not st or not root or st.hidden or spot:GetAttribute("Occupant") then
		return
	end
	st.hidden = spot
	st.hideFrom = root.CFrame
	spot:SetAttribute("Occupant", player.Name)
	root.Anchored = true
	root.CFrame = spot.Inside.CFrame
	player:SetAttribute("Hidden", true)
end
function unhide(player, pushOut)
	local st = roster[player]
	if not st or not st.hidden then
		return
	end
	local spot = st.hidden
	st.hidden = nil
	spot:SetAttribute("Occupant", nil)
	player:SetAttribute("Hidden", false)
	local _, root = charParts(player)
	if root then
		local out = spot.Door.Position + (spot.Door.Position - spot.Inside.Position).Unit * 3
		root.CFrame = CFrame.new(Vector3.new(out.X, spot.Inside.Position.Y, out.Z))
		root.Anchored = false
	end
end
for _, spot in hideSpots do
	local pr = prompt(spot.Door, "Hide", (spot.Name:gsub("(%l)(%u)", "%1 %2")), 0, 7)
	onTrigger(pr, function(player)
		if roster[player] and not roster[player].busy then
			hide(player, spot)
		end
	end)
end
LeaveHide.OnServerEvent:Connect(function(player)
	unhide(player)
end)
StateRemote.OnServerEvent:Connect(function(player, state)
	local st = roster[player]
	if st and type(state) == "table" then
		st.sprinting = state.Sprinting == true
		st.moving = state.Moving == true
		st.flashlight = state.Flashlight == true
	end
end)

-- CAUGHT -------------------------------------------------------------------------------
local function sendToLobby(list, completed)
	if RunService:IsStudio() then
		for _, p in list do
			Notify:FireClient(p, "(Studio) Teleports only work in the published game.")
		end
		return
	end
	if #list == 0 then
		return
	end
	-- one teleport per player so each carries their own earnings back to the lobby bank
	for _, p in list do
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({ Completed = completed, Earned = math.clamp(p:GetAttribute("RunCash") or 0, 0, Config.MaxEarnedPerRun or 2000), From = 4, Secret = p:GetAttribute("SecretEnding") and 4 or nil })
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(PlaceIds.Lobby, { p }, options)
		end)
		if not ok then
			warn("Teleport failed: " .. tostring(err))
		end
	end
end
function catchPlayer(m, player)
	local st = roster[player]
	if not st or st.beingCaught or player:GetAttribute("AdminGod") or os.clock() < (st.protectedUntil or 0) or st.zipping then
		return
	end
	st.beingCaught = true
	st.busy = nil
	if st.hidden then
		unhide(player, true)
	end
	if not st.infinite then
		st.lives -= 1
		player:SetAttribute("Lives", st.lives)
		savedLives[player.UserId] = st.lives
	end
	Caught:FireClient(player, m.kind, st.infinite and -1 or st.lives)
	MinigameRemote:FireClient(player, "cancel")
	local _, root = charParts(player)
	if root then
		root.Anchored = true
	end
	m.stunnedUntil = os.clock() + 3
	m.state = "Patrol"
	m.target = nil
	m.waypoints = nil
	m.huntUntil = nil
	m.model:SetAttribute("Chasing", nil)
	task.delay(2.4, function()
		st.beingCaught = false
		if not player.Parent or not roster[player] then
			return
		end
		if st.lives <= 0 then
			notifyAll(player.DisplayName .. " was taken by Wildcrest.", Color3.fromRGB(255, 80, 80))
			roster[player] = nil
			player:SetAttribute("InGame", false)
			savedLives[player.UserId] = nil
			sendToLobby({ player })
			if RunService:IsStudio() then
				task.delay(2, function()
					if player.Parent then
						player:LoadCharacter()
					end
				end)
			end
			return
		end
		local _, r2 = charParts(player)
		if r2 then
			r2.CFrame = (round.respawnCF or start.CFrame) + Vector3.new(math.random(-3, 3), 3, 0)
			r2.Anchored = false
		end
		st.protectedUntil = os.clock() + D().Protect
		player:SetAttribute("Protected", true)
		task.delay(D().Protect, function()
			if player.Parent then
				player:SetAttribute("Protected", nil)
			end
		end)
		-- no spawn camping
		local home = (round.respawnCF or start.CFrame).Position
		for _, mon in monsters do
			if not mon.dead and not mon.inVent and (mon.feetPos - home).Magnitude < 40 then
				local list = patrolByFloor[mon.kind == "Guard" and mon.home or floorOf(mon.feetPos.Y)]
				local far, farD = nil, 0
				for _, pt in list do
					local d = (pt - home).Magnitude
					if d > farD then
						far, farD = pt, d
					end
				end
				if far then
					mon.feetPos = far
					mon.waypoints = nil
					mon.state = "Patrol"
					mon.idleUntil = os.clock() + 4
				end
			end
		end
		Notify:FireClient(player, st.infinite and "You got away... barely." or ("You got away... barely. Lives left: " .. st.lives))
	end)
end

-- the guards' tasers / B-01 / Marsh: breath-holding while hiding
task.spawn(function()
	while true do
		task.wait(1)
		if round.active then
			for _, p in inGamePlayers() do
				local st = roster[p]
				if st.hidden and not st.breathing and os.clock() > (st.nextBreath or 0) then
					for _, m in monsters do
						if not m.dead and not m.inVent and m.kind ~= "Guard" and (m.root.Position - st.hidden.Inside.Position).Magnitude < 15 then
							st.breathing = true
							st.breathMonster = m
							st.pending = { kind = "breath", started = os.clock(), minTime = 0, onDone = function(ok)
								st.breathing = false
								st.nextBreath = os.clock() + 5
								if not ok and st.hidden and st.breathMonster and not st.breathMonster.dead then
									Notify:FireClient(p, "You gasped for air... it HEARD you!", Color3.fromRGB(255, 80, 80))
									st.breathMonster.state = "Hunt"
									st.breathMonster.huntHidden = st.hidden
								end
							end }
							MinigameRemote:FireClient(p, "breath", { time = 6 })
							break
						end
					end
				end
			end
		end
	end
end)

-- MINI-GAMES: the server asks the client to play one, the client reports back ------------
local function startMinigame(player, kind, data, minTime, onDone)
	local st = roster[player]
	if not st or st.pending or st.hidden or st.beingCaught then
		return false
	end
	st.pending = { kind = kind, started = os.clock(), minTime = minTime or 1, onDone = onDone }
	st.busy = true
	MinigameRemote:FireClient(player, kind, data or {})
	return true
end
MinigameResult.OnServerEvent:Connect(function(player, kind, success, payload)
	local st = roster[player]
	if not st or not st.pending or st.pending.kind ~= kind then
		return
	end
	local pend = st.pending
	st.pending = nil
	st.busy = nil
	if success == true and os.clock() - pend.started < pend.minTime then
		success = false -- too fast to be real
	end
	local ok, err = pcall(pend.onDone, success == true, payload)
	if not ok then
		warn("minigame " .. kind .. ": " .. tostring(err))
	end
end)

-- CUTSCENES: freeze the world, every client plays it --------------------------------------
local function cutscene(name, duration, args)
	round.cutsceneUntil = os.clock() + duration
	for _, p in inGamePlayers() do
		local _, root = charParts(p)
		local st = roster[p]
		if root and not (st and st.hidden) then
			root.Anchored = true
			task.delay(duration, function()
				if root.Parent and not (roster[p] and roster[p].hidden) and not (roster[p] and roster[p].zipping) then
					root.Anchored = false
				end
			end)
		end
		MinigameRemote:FireClient(p, "cancel")
		if roster[p] then
			roster[p].pending = nil
			roster[p].busy = nil
		end
		CutsceneRemote:FireClient(p, name, args or {})
	end
end
local function nearestPlayerTo(pos)
	local best, bd
	for _, p in inGamePlayers() do
		local _, r = charParts(p)
		if r then
			local d = (r.Position - pos).Magnitude
			if not bd or d < bd then
				best, bd = p, d
			end
		end
	end
	return best
end
local function forceHunt(m, seconds, target)
	if not m then
		return
	end
	m.huntTarget = target or nearestPlayerTo(m.feetPos)
	m.huntUntil = os.clock() + seconds
end

-- CHAPTER 4 - PART 1: THE RAID ---------------------------------------------------------
-- Wildcrest raids your apartment tower. Balcony -> ledge -> neighbor -> stairs (SWAT below) ->
-- floor 10 -> pry the elevator, slide the cable -> hatch -> sneak past Marsh in the lobby -> alley -> subway.
local H = 14
local F12, F10 = 11 * H, 9 * H
local Mk = level:WaitForChild("Markers")
local function mk(name)
	return Mk:FindFirstChild(name)
end
local props12 = level.F12.Props
local DOORS = {
	FrontDoor = props12.FrontDoor,
	NeighborDoor = props12.NeighborDoor,
	StairDoor12 = props12.StairDoor12,
	StairDoor10 = level.StairDoors.StairDoor10,
	BackDoor = level.F1.Service.BackDoor,
}
for _, d in DOORS do
	setDoor(d, false)
end
local function openDoor(d)
	round.unlocked[d.Name] = true
	setDoor(d, true)
end
local function playerIn(a, b)
	for _, p in inGamePlayers() do
		local _, r = charParts(p)
		if r then
			local q = r.Position
			if q.X >= a.X and q.X <= b.X and q.Y >= a.Y and q.Y <= b.Y and q.Z >= a.Z and q.Z <= b.Z then
				return p
			end
		end
	end
end
local function spawnGuard(markName, homeFloor)
	local m = mk(markName)
	if not m then
		return
	end
	local g = spawnMonster("Guard", CFrame.new(m.Position), homeFloor)
	g.idleUntil = os.clock() + 2
	return g
end
local function setMarker(pos, name)
	ReplicatedStorage:SetAttribute("MarkerPos", pos)
	ReplicatedStorage:SetAttribute("MarkerName", name or "")
end
local function slideDoors(model, gap)
	for _, n in { "DoorL", "DoorR" } do
		local p = model:FindFirstChild(n)
		if p then
			p:SetAttribute("Home", p:GetAttribute("Home") or p.CFrame)
			TweenService:Create(p, TweenInfo.new(1.2), { CFrame = p:GetAttribute("Home") * CFrame.new(n == "DoorL" and -gap or gap, 0, 0) }):Play()
		end
	end
end
-- Marsh stands in the lobby giving orders (he does not chase in part 1)
local lobbyMarsh
local function placeLobbyMarsh(on)
	if lobbyMarsh then
		lobbyMarsh:Destroy()
		lobbyMarsh = nil
	end
	local srcM = ServerStorage.Monsters:FindFirstChild("Marsh")
	local mpos = mk("MarshLobby")
	if not on or not srcM or not mpos then
		return
	end
	local m = srcM:Clone()
	m.Name = "LobbyMarsh"
	m:PivotTo(CFrame.lookAt(mpos.Position, mpos.Position + Vector3.new(0, 0, 1)) + Vector3.new(0, m:GetAttribute("HipHeight") or 3, 0))
	m.Parent = itemsFolder
	local hum = m:FindFirstChildOfClass("Humanoid")
	local animator = hum and (hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum))
	if animator then
		local a = Instance.new("Animation")
		a.AnimationId = "rbxassetid://" .. Config.Monsters.Marsh.Anim.idle
		pcall(function()
			local t = animator:LoadAnimation(a)
			t.Looped = true
			t:Play()
		end)
	end
	lobbyMarsh = m
end

local function breach()
	if round.breached then
		return
	end
	round.breached = true
	openDoor(DOORS.FrontDoor)
	sound(Config.Sounds.Jumpscare, DOORS.FrontDoor, 0.8, 0.45)
	pa("BREACH! BREACH! GO GO GO!", "SWAT")
	local g = spawnMonster("Guard", CFrame.new(-18.5, F12, -1), 12)
	g.idleUntil = os.clock() + 0.3
	if round.phase == 1 then
		forceHunt(g, 6)
	end
end
local function startRaid()
	local id = round.id
	cutscene("raid", 12, {})
	task.delay(12, function()
		if round.id ~= id then
			return
		end
		setObjective("WILDCREST IS AT YOUR DOOR! Escape through the BALCONY (living room) and climb across the ledge to your neighbor's.")
		setMarker(Vector3.new(-13, F12 + 2, -31.2), "LEDGE")
		notifyAll("They're about to break the door down. GO!", Color3.fromRGB(255, 120, 80))
	end)
	local wait = (Config.BreachTime and Config.BreachTime[round.difficulty or "Normal"]) or 50
	task.delay(12 + wait, function()
		if round.id == id then
			breach()
		end
	end)
end
local function startLobby()
	local id = round.id
	setPhase(5)
	placeLobbyMarsh(true)
	for i = 1, math.clamp(D().Guards, 1, 4) do
		spawnGuard("GuardLobby" .. i, 1)
	end
	cutscene("lobby", 12, {})
	task.delay(12, function()
		if round.id ~= id then
			return
		end
		setObjective("Squeeze out of the elevator and sneak to the SERVICE DOOR (left of the elevator). Don't let them see you!")
		setMarker(Vector3.new(-14, 4, 4), "SERVICE DOOR")
	end)
end

onTrigger(prompt(DOORS.NeighborDoor, "Open", "Front door", 0, 7), function(player)
	if roster[player] then
		openDoor(DOORS.NeighborDoor)
	end
end)
onTrigger(prompt(DOORS.FrontDoor, "Open", "Your front door", 0, 7), function(player)
	if roster[player] then
		Notify:FireClient(player, "They're RIGHT outside! Not that way - the balcony!", Color3.fromRGB(255, 120, 80))
	end
end)
onTrigger(prompt(DOORS.StairDoor12, "Open", "Stairwell", 0, 7), function(player)
	if roster[player] then
		openDoor(DOORS.StairDoor12)
	end
end)
onTrigger(prompt(DOORS.StairDoor10, "Open", "Floor 10", 0, 7), function(player)
	if roster[player] then
		openDoor(DOORS.StairDoor10)
	end
end)
onTrigger(prompt(DOORS.BackDoor, "Push Open", "Back exit", 0, 7), function(player)
	if roster[player] then
		openDoor(DOORS.BackDoor)
	end
end)
local e10 = level.Shaft.F10.ElevatorDoor
local e1 = level.Shaft.F1.ElevatorDoor
local car = level.F1.ElevatorCar
local pryPrompt = prompt(e10.DoorL, "Pry Open", "Elevator doors", 2.5, 7)
onTrigger(pryPrompt, function(player)
	if not roster[player] or round.pried then
		return
	end
	round.pried = true
	pryPrompt.Enabled = false
	slideDoors(e10, 1.5)
	notifyAll("The doors grind open. A long drop... and the elevator CABLES.", Color3.fromRGB(255, 220, 140))
	setObjective("Grab the CABLE and slide down the elevator shaft.")
	setMarker(level.Shaft.CableGrab.Position, "CABLE")
end)
onTrigger(prompt(level.Shaft.CableGrab, "Slide Down", "Elevator cable", 0.4, 8), function(player)
	local st = roster[player]
	local _, root = charParts(player)
	if not st or not root or not round.pried or st.zipping or st.hidden then
		return
	end
	st.zipping = true
	local from = level.Shaft.CableGrab.Position
	local to = Vector3.new(-1.5, 12.5, 5.5)
	local dur = 4.5
	root.Anchored = true
	ZipRemote:FireClient(player, from, to, dur)
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < dur and root.Parent do
			local k = (os.clock() - t0) / dur
			root.CFrame = CFrame.new(from:Lerp(to, k * k))
			RunService.Heartbeat:Wait()
		end
		if root.Parent then
			root.CFrame = CFrame.new(to)
			root.Anchored = false
		end
		st.zipping = false
		round.respawnCF = CFrame.new(-1.5, 12.5, 5.5)
		if not round.onCar then
			round.onCar = true
			setObjective("You landed on top of the elevator. Open the HATCH and drop in.")
			setMarker(car.Hatch.Position, "HATCH")
		end
	end)
end)
onTrigger(prompt(car.Hatch, "Drop In", "Hatch", 0.3, 7), function(player)
	local _, root = charParts(player)
	if not roster[player] or not root then
		return
	end
	root.CFrame = CFrame.new(-2, 3.2, 8.5)
	round.respawnCF = CFrame.new(-2, 3.2, 8.5)
	if not round.inLobby then
		round.inLobby = true
		startLobby()
	end
end)
local squeeze = prompt(e1.DoorL, "Squeeze Out", "Elevator doors", 1.5, 7)
onTrigger(squeeze, function(player)
	if not roster[player] or round.squeezed then
		return
	end
	round.squeezed = true
	squeeze.Enabled = false
	slideDoors(e1, 1.5)
end)
local marshLines = { "Twelve floors and you can't find ONE employee?", "Check every closet. Every vent.", "Nobody leaves this building.", "If they reach the street, you're all fired." }
task.spawn(function()
	while true do
		task.wait(0.3)
		if round.active and not round.ending and round.phase >= 1 and os.clock() >= (round.cutsceneUntil or 0) then
			-- no skipping the tower: anyone who falls/jumps out early goes back to their checkpoint
			if round.phase <= 4 then
				for _, p in inGamePlayers() do
					local st = roster[p]
					local _, r = charParts(p)
					if r and st and not st.zipping and not st.beingCaught and not st.hidden then
						local q = r.Position
						local outside = q.X < -41 or q.X > 41 or q.Z < -36.5 or q.Z > 31
						if (outside and q.Y < F12 - 4) or q.Y < -20 then
							r.AssemblyLinearVelocity = Vector3.zero
							r.CFrame = (round.respawnCF or CFrame.new(start.Position)) + Vector3.new(0, 1, 0)
							Notify:FireClient(p, "Whoa - that's a 12-floor drop! Back you go.", Color3.fromRGB(255, 200, 120))
						end
					end
				end
			end
			local id = round.id
			if round.phase == 1 and playerIn(Vector3.new(-14, F12 - 2, -30), Vector3.new(12, F12 + 6, -4)) then
				setPhase(2)
				round.respawnCF = CFrame.new(-6, F12 + 3, -20)
				setObjective("You made it across. Sneak out your neighbor's FRONT DOOR and get to the STAIRS (east end of the hallway).")
				setMarker(DOORS.StairDoor12.Position, "STAIRS")
				breach()
				if D().Guards >= 4 then
					spawnGuard("GuardF12b", 12)
				end
			elseif round.phase == 2 and playerIn(Vector3.new(28, F12 - 9, 4), Vector3.new(40, F12 + 6, 20)) then
				setPhase(3)
				round.respawnCF = CFrame.new(36, F12 + 3, 5.5)
				setObjective("Run DOWN the stairs. Fast.")
				setMarker(nil)
			elseif round.phase == 3 and not round.swat and playerIn(Vector3.new(28, F10 - 1, 4), Vector3.new(40, F10 + 8, 20)) then
				round.swat = true
				cutscene("swat", 8, {})
				task.delay(8, function()
					if round.id ~= id then
						return
					end
					setObjective("SWAT is coming UP the stairs! Get out on FLOOR 10 and find another way down.")
					setMarker(DOORS.StairDoor10.Position, "FLOOR 10")
					round.respawnCF = CFrame.new(31, F10 + 3, 5.5)
				end)
			elseif round.phase == 3 and round.swat and playerIn(Vector3.new(-40, F10 - 1, -4), Vector3.new(28, F10 + 8, 4)) then
				setPhase(4)
				round.respawnCF = CFrame.new(24, F10 + 3, 0)
				setObjective("The elevator's dead... but the SHAFT isn't. Pry the elevator doors open.")
				setMarker(e10.DoorL.Position, "ELEVATOR")
				if D().Guards >= 2 then
					spawnGuard("GuardF10", 10)
				end
			elseif round.phase == 5 and not round.service and playerIn(Vector3.new(-40, -2, 4.5), Vector3.new(-6.5, 9, 30)) then
				round.service = true
				round.respawnCF = CFrame.new(-30, 3, 9)
				setObjective("Out the BACK DOOR (north wall) into the alley!")
				setMarker(DOORS.BackDoor.Position, "BACK DOOR")
			elseif round.phase == 5 and playerIn(Vector3.new(-60, -2, 30.5), Vector3.new(60, 12, 50)) then
				setPhase(6)
				round.respawnCF = CFrame.new(-22, 3, 38)
				setObjective("RUN! Get to the SUBWAY ENTRANCE - down the alley, then left.")
				setMarker(exitZone.Position, "SUBWAY")
				pa("They're OUTSIDE! Cover the street!", "MARSH")
			end
			if round.phase == 5 and os.clock() > (round.nextBark or 0) then
				round.nextBark = os.clock() + 15
				if os.clock() > (round.cutsceneUntil or 0) + 3 then
					pa(marshLines[math.random(#marshLines)], "MARSH")
				end
			end
		end
	end
end)

-- CHAPTER 4 - PART 2: OLD TOWN STATION (horror starts) ----------------------------------
-- ticket hall: pick the station master's lock -> station key -> service gate in the shutter ->
-- platform (something on the tracks...) -> cut TRACK POWER in the signal room -> into the tunnel.
local sub = workspace:WaitForChild("Subway")
local hall = sub.TicketHall
local plat = sub.Platform
local subwayZone = exterior:WaitForChild("SubwayZone")
local officeDoor = hall.Office.OfficeDoor
local serviceGate = hall.Shutter.ServiceGate
local powerLever = plat.SignalRoom.PowerLever
local powerLight = plat.SignalRoom.PowerLight
setDoor(officeDoor, false)
setDoor(serviceGate, false)
local function inPart(part, pad)
	pad = pad or 0
	for _, p in inGamePlayers() do
		local _, r = charParts(p)
		if r then
			local rel = part.CFrame:PointToObjectSpace(r.Position)
			local h = part.Size / 2
			if math.abs(rel.X) <= h.X + pad and math.abs(rel.Y) <= h.Y + 3 + pad and math.abs(rel.Z) <= h.Z + pad then
				return p
			end
		end
	end
end
local function spawnStationKey()
	local k = itemPart("StationKey", Vector3.new(0.4, 0.15, 1.2), Color3.fromRGB(255, 200, 70), CFrame.new(-68, -11.3, 92.5) * CFrame.Angles(0, 0.5, 0))
	onTrigger(prompt(k, "Take", "Station Key", 0.3), function(player)
		if roster[player] and k.Parent then
			k:Destroy()
			round.stationKey = true
			ReplicatedStorage:SetAttribute("StationKey", true)
			notifyAll(player.DisplayName .. " found the STATION KEY.", Color3.fromRGB(255, 210, 110))
			setObjective("Use the STATION KEY on the SERVICE GATE in the shutter.")
			setMarker(serviceGate.Position, "SERVICE GATE")
		end
	end)
	local log = itemPart("StationLog", Vector3.new(1, 0.08, 1.3), Color3.fromRGB(230, 225, 200), CFrame.new(-69, -11.35, 91) * CFrame.Angles(0, -0.3, 0))
	log.Material = Enum.Material.SmoothPlastic
	onTrigger(prompt(log, "Read", "Station Master's Log", 0), function(player)
		ShowNote:FireClient(player, "STATION MASTER'S LOG",
			"Oct 2 - Wildcrest bought the old line today. They say it's for 'cargo'.\n\nOct 9 - Their trucks come at night. Big crates. Air holes.\n\nOct 15 - Something in the tunnel past Section 1 screams when the trains go by. The Wildcrest men laughed and told me to cut the track power and keep the gates shut.\n\nOct 16 - I am not coming back.")
	end)
end
onTrigger(prompt(officeDoor, "Pick Lock", "Station Master's office", 0, 7), function(player)
	if not roster[player] or round.unlocked[officeDoor.Name] then
		return
	end
	startMinigame(player, "lockpick", {}, 2, function(ok)
		if ok then
			openDoor(officeDoor)
			Notify:FireClient(player, "Click. The office door creaks open.", Color3.fromRGB(200, 230, 255))
			setMarker(Vector3.new(-68, -11, 92.5), "STATION KEY")
		else
			Notify:FireClient(player, "The pick slipped. Try again.")
		end
	end)
end)
onTrigger(prompt(serviceGate, "Unlock", "Service gate", 0.5, 7), function(player)
	if not roster[player] then
		return
	end
	if not round.stationKey then
		Notify:FireClient(player, "Locked. It needs the STATION KEY.")
		return
	end
	if not round.unlocked[serviceGate.Name] then
		openDoor(serviceGate)
		setPhase(8)
		round.respawnCF = CFrame.new(-45, -11, 104)
		setObjective("Go DOWN to the platform.")
		setMarker(Vector3.new(-45, -27, 136), "PLATFORM")
	end
end)
local leverPrompt = prompt(powerLever, "Cut Power", "Track power", 2, 7)
onTrigger(leverPrompt, function(player)
	if not roster[player] or round.powerOff then
		return
	end
	round.powerOff = true
	leverPrompt.Enabled = false
	powerLever:SetAttribute("Home", powerLever:GetAttribute("Home") or powerLever.CFrame)
	TweenService:Create(powerLever, TweenInfo.new(0.3), { CFrame = powerLever:GetAttribute("Home") * CFrame.new(0, -1.6, 0) }):Play()
	powerLight.Color = Color3.fromRGB(60, 255, 90)
	local pl = powerLight:FindFirstChildOfClass("PointLight")
	if pl then
		pl.Color = Color3.fromRGB(60, 255, 90)
	end
	setPhase(10)
	ReplicatedStorage:SetAttribute("TrackPower", false)
	round.respawnCF = CFrame.new(-45, -27, 226)
	setObjective("Track power OFF. Climb down onto the tracks at the NORTH END and go into the TUNNEL.")
	setMarker(Vector3.new(-69.5, -31, 252), "TUNNEL")
	pa("Who just cut the power on Section One?! ...They're going into the tunnel. Send everyone. NOW.", "MARSH")
	for _, m in monsters do
		if m.kind == "Guard" and not m.dead and m.home == 21 then
			forceHunt(m, 10)
		end
	end
end)
local stationLines = {
	"Attention passengers. This station is closed. Please remain where you are.",
	"Wildcrest Transit reminds you: there is no way out.",
	"Security to Old Town. The ex-employee is somewhere in this station.",
	"Next train... arriving... never.",
	"Have you seen this tour guest? Report any sightings to Wildcrest staff.",
}
task.spawn(function()
	while true do
		task.wait(0.3)
		if round.active and not round.ending and round.phase >= 6 and os.clock() >= (round.cutsceneUntil or 0) then
			local id = round.id
			if round.phase == 6 and (inPart(subwayZone) or playerIn(Vector3.new(-50, -16, 60), Vector3.new(-18, 2, 112))) then
				setPhase(7)
				round.respawnCF = CFrame.new(-45, -11, 84)
				cutscene("arrive", 9, {})
				task.delay(9, function()
					if round.id ~= id then
						return
					end
					setObjective("The SHUTTER is locked. The STATION KEY should be in the STATION MASTER'S office (left side).")
					setMarker(officeDoor.Position, "STATION MASTER")
				end)
				-- the guards follow you down a little later
				task.delay(9 + Config.StationGuardDelay, function()
					if round.id ~= id or round.phase > 8 then
						return
					end
					pa("All units: the target went down into Old Town station. Seal it and search it.", "MARSH")
					spawnGuard("GuardHall1", 20)
					if D().Guards >= 2 then
						spawnGuard("GuardHall2", 20)
					end
				end)
			elseif round.phase == 8 and playerIn(Vector3.new(-62, -33, 118), Vector3.new(-28, -24, 244)) then
				setPhase(9)
				round.respawnCF = CFrame.new(-45, -27, 138)
				cutscene("platform", 10, {})
				task.delay(10, function()
					if round.id ~= id then
						return
					end
					setObjective("Don't touch the tracks - the rail is LIVE. Cut the TRACK POWER in the SIGNAL ROOM (north end of the platform).")
					setMarker(powerLever.Position, "SIGNAL ROOM")
					if D().Guards >= 2 then
						spawnGuard("GuardPlat1", 21)
					end
					if D().Guards >= 4 then
						spawnGuard("GuardPlat2", 21)
					end
				end)
			end
			-- the live rail: step on the tracks before the power is cut and you get thrown back
			if not round.powerOff then
				for _, p in inGamePlayers() do
					local st = roster[p]
					local _, r = charParts(p)
					if r and st and not st.hidden and not st.beingCaught then
						local q = r.Position
						if q.Y < -28.6 and q.Y > -40 and q.Z > 118 and q.Z < 300 and (q.X < -62.2 or q.X > -27.8) and os.clock() > (st.zapAt or 0) then
							st.zapAt = os.clock() + 1.5
							r.AssemblyLinearVelocity = Vector3.zero
							r.CFrame = CFrame.new(q.X < -45 and -58 or -32, -27, math.clamp(q.Z, 122, 240))
							Notify:FireClient(p, "ZZZT! The rail is LIVE! Find the track power switch first.", Color3.fromRGB(255, 240, 120))
							StateRemote:FireClient(p, "zap")
						end
					end
				end
			end
			if round.phase >= 7 and round.phase <= 10 and os.clock() > (round.nextStationPA or 0) then
				round.nextStationPA = os.clock() + math.random(22, 34)
				pa(stationLines[math.random(#stationLines)], "STATION PA")
			end
		end
	end
end)

-- CHAPTER 4 - PART 3: THE DARK TUNNEL ---------------------------------------------------
-- no lights. runaway trains (dive into the ALCOVES). halfway, something drops from the ceiling.
local tunnel = sub:WaitForChild("Tunnel1")
local TRACK_X = -69.5
local function inTunnel(q)
	return q.Z > 247 and q.Z < 704 and q.Y < -28 and q.Y > -40 and q.X > -83 and q.X < -46 -- (alcoves + maintenance room count too)
end
local function buildTrain()
	local m = Instance.new("Model")
	m.Name = "RunawayTrain"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored, body.CanCollide, body.CanQuery = true, false, false
	body.Size = Vector3.new(13.6, 10, 46) -- fills the tunnel: only the alcoves are safe
	body.Color = Color3.fromRGB(120, 125, 120)
	body.Material = Enum.Material.Metal
	body.Parent = m
	m.PrimaryPart = body
	for _, zf in { -1, 1 } do
		local face = Instance.new("Part")
		face.Name = "Face"
		face.Anchored, face.CanCollide, face.CanQuery = true, false, false
		face.Size = Vector3.new(12, 3, 0.4)
		face.Color = Color3.fromRGB(255, 245, 200)
		face.Material = Enum.Material.Neon
		face.CFrame = CFrame.new(0, 1, zf * 23.1)
		face.Parent = m
		local sl = Instance.new("SpotLight")
		sl.Face = zf > 0 and Enum.NormalId.Back or Enum.NormalId.Front
		sl.Range = 60
		sl.Angle = 50
		sl.Brightness = 6
		sl.Parent = face
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = body, face
		w.Parent = face
	end
	local horn = Instance.new("Sound")
	horn.Name = "Roar"
	horn.SoundId = Config.Sounds.Alarm
	horn.PlaybackSpeed = 0.45
	horn.Volume = 3
	horn.RollOffMaxDistance = 300
	horn.Looped = true
	horn.Parent = body
	m.Parent = itemsFolder
	return m
end
local trainVictim = { kind = "Train", stunnedUntil = 0, state = "Patrol" }
local function runTrain(dir)
	local id = round.id
	local zStart, zEnd = dir > 0 and 236 or 712, dir > 0 and 712 or 236
	for _, p in inGamePlayers() do
		StateRemote:FireClient(p, "train", zStart, dir, 4)
	end
	task.wait(4)
	if round.id ~= id or round.ending then
		return
	end
	local m = buildTrain()
	trainVictim.model = m
	local z = zStart
	local horn = m.Body:FindFirstChild("Roar")
	horn:Play()
	while round.id == id and (dir > 0 and z < zEnd or dir < 0 and z > zEnd) do
		local dt = RunService.Heartbeat:Wait()
		z += dir * Config.TrainSpeed * dt
		m:PivotTo(CFrame.new(TRACK_X, -28.5, z) * (dir < 0 and CFrame.Angles(0, math.pi, 0) or CFrame.new()))
		for _, p in inGamePlayers() do
			local st = roster[p]
			local _, r = charParts(p)
			if r and st and not st.hidden and not st.beingCaught and not p:GetAttribute("AdminGod") then
				local q = r.Position
				if math.abs(q.X - TRACK_X) < 7.1 and math.abs(q.Z - z) < 24 and q.Y < -24 and q.Y > -38 then
					catchPlayer(trainVictim, p)
				end
			end
		end
	end
	m:Destroy()
end
local function spawnThing(pos)
	local t = spawnMonster("Thing", CFrame.new(pos), 22)
	t.idleUntil = os.clock() + 1
	return t
end
task.spawn(function()
	while true do
		task.wait(0.3)
		if round.active and not round.ending and round.phase >= 10 and round.phase <= 13 and os.clock() >= (round.cutsceneUntil or 0) then
			local id = round.id
			local anyIn = false
			local farthest = 0
			for _, p in inGamePlayers() do
				local _, r = charParts(p)
				if r and inTunnel(r.Position) then
					anyIn = true
					farthest = math.max(farthest, r.Position.Z)
				end
			end
			if round.phase == 10 and anyIn then
				setPhase(11)
				round.respawnCF = CFrame.new(TRACK_X, -31, 252)
				setObjective("Follow the tunnel to the next station. If you hear a TRAIN coming - get into an ALCOVE (white marks on the walls)!")
				setMarker(nil)
				round.nextTrain = os.clock() + 9
			elseif round.phase == 11 and farthest > 410 then
				setPhase(12)
				round.respawnCF = CFrame.new(TRACK_X, -31, 400)
				cutscene("thing", 9, {})
				task.delay(9, function()
					if round.id ~= id then
						return
					end
					local t = spawnThing(Vector3.new(TRACK_X, -34, math.max(260, farthest - 34)))
					forceHunt(t, 9)
					setObjective("RUN! There's a MAINTENANCE ROOM ahead on the right. HIDE in the locker!")
					setMarker(Vector3.new(-59.3, -30, 478.7), "LOCKER")
					round.nextTrain = os.clock() + 25
				end)
			elseif round.phase == 12 and playerIn(Vector3.new(-61, -36, 474), Vector3.new(-46, -24, 490)) then
				setPhase(13)
				round.respawnCF = CFrame.new(-54, -31, 482)
				setObjective("It lost you... for now. Keep going north - something is lit up at the END of the tunnel.")
				setMarker(Vector3.new(TRACK_X, -30, 690), "TUNNEL END")
			end
			if anyIn and round.phase >= 11 and round.nextTrain and os.clock() > round.nextTrain and not round.trainRunning then
				round.trainRunning = true
				round.nextTrain = os.clock() + math.random(Config.TrainEvery[1], Config.TrainEvery[2])
				task.spawn(function()
					local ok, err = pcall(runTrain, math.random() < 0.6 and 1 or -1)
					if not ok then
						warn("train: " .. tostring(err))
					end
					round.trainRunning = false
				end)
			end
		end
	end
end)

-- CHAPTER 4 - PARTS 4-7: CONSTRUCTION, SEWERS, CONTROL CENTER, LAST STOP ---------------
local con = sub:WaitForChild("Construction")
local sew = sub:WaitForChild("Sewers")
local ctl = sub:WaitForChild("Control")
local last = sub:WaitForChild("LastStop")
local ride = workspace:WaitForChild("RideSet")
local liftCage = con.Lift.LiftCage
local cageBottom = liftCage.CFrame
local liftButton = con.Lift.LiftButton
local fallingBeam = con.Walkway.FallingBeam
local beamHome = fallingBeam.CFrame
local exitDoorCC = ctl.ExitDoor
setDoor(exitDoorCC, false)
local gateParts = {}
for _, p in sew.Gate:GetChildren() do
	gateParts[p] = p.CFrame
end
local rideParts = {}
for _, folder in { ride.CarA, ride.CarB } do
	for _, p in folder:GetDescendants() do
		if p:IsA("BasePart") then
			rideParts[p] = p.CFrame
		end
	end
end
local function ensureThing(pos)
	local t = monsterOf("Thing")
	if not t then
		t = spawnThing(pos)
	else
		t.feetPos = pos
		t.waypoints = nil
		t.state = "Patrol"
		t.huntUntil = nil
		t.model:PivotTo(CFrame.new(pos + Vector3.new(0, t.hip, 0)))
	end
	return t
end
local function lure(pos)
	local t = monsterOf("Thing")
	if t then
		t.state = "Search"
		t.lastSeenPos = pos
		t.searchUntil = os.clock() + 10
		computePath(t, pos)
	end
end
local function shakeAll(kind)
	for _, p in inGamePlayers() do
		StateRemote:FireClient(p, kind or "quake")
	end
end
-- PART 4: generator -> lift -> walkway -> ladder -> sewer hatch
local genPrompt = prompt(con.Generator, "Start Generator", "Construction generator", 0, 8)
onTrigger(genPrompt, function(player)
	if not roster[player] or round.liftPower then
		return
	end
	startMinigame(player, "generator", { pulls = 4 }, 3, function(ok)
		if not ok then
			Notify:FireClient(player, "The engine coughed and died. Pull in rhythm!")
			return
		end
		round.liftPower = true
		genPrompt.Enabled = false
		setPhase(15)
		liftButton.Color = Color3.fromRGB(60, 255, 90)
		notifyAll("The generator ROARS to life... and everything in the dark heard it.", Color3.fromRGB(255, 200, 120))
		setObjective("Ride the construction LIFT up to the walkway - FAST.")
		setMarker(liftButton.Position, "LIFT")
		lure(con.Generator.Position - Vector3.new(0, 3, 0))
	end)
end)
onTrigger(prompt(liftButton, "Ride Lift", "Construction lift", 0.3, 8), function(player)
	local st = roster[player]
	local _, root = charParts(player)
	if not st or not root or st.zipping then
		return
	end
	if not round.liftPower then
		Notify:FireClient(player, "No power. Start the GENERATOR first.")
		return
	end
	st.zipping = true
	root.Anchored = true
	local from, to = Vector3.new(-55, -27, 803), Vector3.new(-55, -15, 803)
	TweenService:Create(liftCage, TweenInfo.new(4, Enum.EasingStyle.Sine), { CFrame = cageBottom + Vector3.new(0, 12, 0) }):Play()
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < 4 and root.Parent do
			local k = (os.clock() - t0) / 4
			k = (1 - math.cos(k * math.pi)) / 2
			root.CFrame = CFrame.new(from:Lerp(to, k))
			RunService.Heartbeat:Wait()
		end
		if root.Parent then
			root.CFrame = CFrame.new(to + Vector3.new(0, 0.5, 0))
			root.Anchored = false
		end
		st.zipping = false
		task.delay(2, function()
			TweenService:Create(liftCage, TweenInfo.new(3), { CFrame = cageBottom }):Play()
		end)
	end)
end)
local hatchPrompt = prompt(con.SewerHatch, "Open Hatch", "Sewer access", 1.5, 8)
onTrigger(hatchPrompt, function(player)
	local _, root = charParts(player)
	if not roster[player] or not root or round.phase < 17 then
		return
	end
	root.CFrame = CFrame.new(mk("SewerLanding").Position + Vector3.new(math.random(-2, 2), 0, 0))
	if round.phase == 17 then
		setPhase(18)
		round.respawnCF = CFrame.new(mk("SewerLanding").Position)
		ReplicatedStorage:SetAttribute("Valves", 0)
		setObjective("Close all 3 VALVES to open the sewer gate (0/3). The water slows you down... and IT hunts by SOUND.")
		setMarker(sew.Valves.Valve1.Position, "VALVE")
		ensureThing(mk("SewerThing").Position)
	end
end)
-- ladders: one press carries you up (the shafts are too tight to climb by hand)
local function ladderRide(player, from, to, dur, done)
	local st = roster[player]
	local _, root = charParts(player)
	if not st or not root or st.zipping or st.hidden then
		return
	end
	st.zipping = true
	root.Anchored = true
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < dur and root.Parent do
			local k = (os.clock() - t0) / dur
			root.CFrame = CFrame.new(from:Lerp(to, k))
			RunService.Heartbeat:Wait()
		end
		if root.Parent then
			root.CFrame = CFrame.new(to)
			root.Anchored = false
		end
		st.zipping = false
		if done then
			done()
		end
	end)
end
onTrigger(prompt(sew.LadderBottom, "Climb Up", "Ladder", 0.3, 8), function(player)
	local _, root = charParts(player)
	if not root or round.phase < 19 then
		return
	end
	ladderRide(player, Vector3.new(-60, -55, 1058.3), Vector3.new(-60, -31, 1058.3), 3, function()
		local _, r = charParts(player)
		if r then
			r.CFrame = CFrame.new(-60, -31, 1054)
		end
	end)
end)
onTrigger(prompt(con.Walkway.LadderTop, "Climb Down", "Ladder", 0.3, 7), function(player)
	ladderRide(player, Vector3.new(-51.2, -15, 849.2), Vector3.new(-51.2, -31, 849.2), 2.5)
end)
onTrigger(prompt(con.Walkway.LadderBottom, "Climb Up", "Ladder", 0.3, 7), function(player)
	ladderRide(player, Vector3.new(-51.2, -31, 849.2), Vector3.new(-51.2, -15, 849.2), 2.5)
end)
-- PART 5: three valves open the gate
local function nextValve()
	for i = 1, 3 do
		local v = sew.Valves:FindFirstChild("Valve" .. i)
		if v and not v:GetAttribute("Closed") then
			return v
		end
	end
end
for i = 1, 3 do
	local v = sew.Valves:FindFirstChild("Valve" .. i)
	local pr = prompt(v, "Close Valve", "Valve " .. i, 2.5, 8)
	onTrigger(pr, function(player)
		if not roster[player] or v:GetAttribute("Closed") or round.phase < 18 then
			return
		end
		v:SetAttribute("Closed", true)
		pr.Enabled = false
		TweenService:Create(v, TweenInfo.new(1.5), { CFrame = v:GetAttribute("Home") * CFrame.Angles(math.rad(270), 0, 0) }):Play()
		local l = sew.Valves:FindFirstChild("ValveLight" .. i)
		if l then
			l.Color = Color3.fromRGB(60, 255, 90)
			l.PointLight.Color = l.Color
		end
		round.valves = (round.valves or 0) + 1
		ReplicatedStorage:SetAttribute("Valves", round.valves)
		lure(v.Position - Vector3.new(0, 4, 0)) -- the squealing metal carries through the water
		if round.valves >= 3 then
			for p in gateParts do
				TweenService:Create(p, TweenInfo.new(3), { CFrame = gateParts[p] + Vector3.new(0, 11.5, 0) }):Play()
			end
			sew.Gate.GateBlock.CanCollide = false
			setPhase(19)
			notifyAll("With a groan, the sewer GATE grinds open.", Color3.fromRGB(150, 255, 160))
			setObjective("The gate is open! Climb the LADDER at the far end of the sewer.")
			setMarker(sew.Ladder.Position, "LADDER")
		else
			notifyAll(("Valve closed (%d/3). That noise... it heard that."):format(round.valves), Color3.fromRGB(255, 220, 150))
			setObjective(("Close all 3 VALVES to open the sewer gate (%d/3)."):format(round.valves))
			local nv = nextValve()
			if nv then
				setMarker(nv.Position, "VALVE")
			end
		end
	end)
end
-- PART 6: control center - track switching (simon) + main power (wires)
local switchPrompt = prompt(ctl.SwitchPanel, "Switch Tracks", "Track switching", 0, 8)
local powerPrompt = prompt(ctl.PowerPanel, "Restore Power", "Main power", 0, 8)
local function controlDone()
	if round.switched and round.ccPower and round.phase == 20 then
		setPhase(21)
		openDoor(exitDoorCC)
		setObjective("The last train has power! Get to PLATFORM 9 - LAST STOP (the red door, north wall).")
		setMarker(exitDoorCC.Position, "LAST STOP")
		pa("A train? You think a TRAIN will save you? ...Fine. Take it. It goes exactly where I want it to.", "MARSH")
	elseif round.phase == 20 then
		local which = round.switched and ctl.PowerPanel or ctl.SwitchPanel
		setMarker(which.Position, round.switched and "MAIN POWER" or "TRACK SWITCH")
	end
end
onTrigger(switchPrompt, function(player)
	if not roster[player] or round.switched or round.phase < 20 then
		return
	end
	startMinigame(player, "simon", { length = 5 }, 4, function(ok)
		if not ok then
			Notify:FireClient(player, "Wrong sequence. Watch the lights.")
			return
		end
		round.switched = true
		switchPrompt.Enabled = false
		local l = ctl:FindFirstChild("SwitchPanelLight")
		if l then
			l.Color = Color3.fromRGB(60, 255, 90)
			l.PointLight.Color = l.Color
		end
		notifyAll("Tracks switched to PLATFORM 9.", Color3.fromRGB(150, 210, 255))
		controlDone()
	end)
end)
onTrigger(powerPrompt, function(player)
	if not roster[player] or round.ccPower or round.phase < 20 then
		return
	end
	startMinigame(player, "wires", {}, 3, function(ok)
		if not ok then
			Notify:FireClient(player, "Sparks! Wrong wire. Try again.")
			return
		end
		round.ccPower = true
		powerPrompt.Enabled = false
		local l = ctl:FindFirstChild("PowerPanelLight")
		if l then
			l.Color = Color3.fromRGB(60, 255, 90)
			l.PointLight.Color = l.Color
		end
		notifyAll("Main power restored. Somewhere above, a train engine hums awake.", Color3.fromRGB(255, 220, 120))
		controlDone()
	end)
end)
-- PART 7: board -> the ride -> uncouple -> the island map
local boardPrompt = prompt(last.BoardPoint, "Board", "The last train", 0.5, 9)
local function spawnMap()
	local m = itemPart("IslandMap", Vector3.new(1.6, 0.08, 1.2), Color3.fromRGB(240, 220, 160), CFrame.new(ride.CarC.MapSpot.Position) * CFrame.Angles(0, 0.3, 0))
	m.Material = Enum.Material.SmoothPlastic
	onTrigger(prompt(m, "Take", "Folded map", 0.5, 8), function(player)
		if roster[player] and m.Parent and round.uncoupled then
			m:Destroy()
			ShowNote:FireClient(player, "WILDCREST - PROJECT B - ISLAND SITE", "A hand-drawn map of an island far off the coast.\n\nMarked in red: 'B-02 HOLDING'. 'B-03'. 'B-04'...\n\nAt the bottom, in Marsh's handwriting:\n'Ship the ex-employee here when caught. Alive.'")
			task.delay(4, function()
				if round.win then
					round.win()
				end
			end)
		end
	end)
end
onTrigger(boardPrompt, function(player)
	if not roster[player] or round.phase < 22 or round.boarded then
		return
	end
	round.boarded = true
	boardPrompt.Enabled = false
	local id = round.id
	cutscene("depart", 9, {})
	task.delay(9, function()
		if round.id ~= id then
			return
		end
		-- everyone rides; the guards / Marsh are left on the platform
		for _, m in table.clone(monsters) do
			if m.kind ~= "Thing" then
				m.dead = true
				m.model:Destroy()
			end
		end
		local startPos = mk("RideStart").Position
		for i, p in inGamePlayers() do
			local _, r = charParts(p)
			if r then
				r.CFrame = CFrame.new(startPos + Vector3.new((i % 3 - 1) * 2, 0, -(i // 3) * 2))
			end
		end
		setPhase(23)
		ReplicatedStorage:SetAttribute("Riding", true)
		round.respawnCF = CFrame.new(startPos + Vector3.new(0, 0, 50))
		setObjective("You made it onto the train... wait. Something just slammed into the BACK of the car.")
		setMarker(nil)
		task.delay(3, function()
			if round.id ~= id then
				return
			end
			shakeAll("quake")
			local t = ensureThing(mk("RideThing").Position)
			forceHunt(t, 40)
			setObjective("IT'S ON THE TRAIN! Run to the FRONT car and pull the EMERGENCY UNCOUPLE lever!")
			setMarker(ride.CarC.CouplingLever.Position, "UNCOUPLE")
		end)
	end)
end)
local couplePrompt = prompt(ride.CarC.CouplingLever, "Uncouple", "Emergency uncouple", 2.5, 8)
onTrigger(couplePrompt, function(player)
	if not roster[player] or round.phase ~= 23 or round.uncoupled then
		return
	end
	round.uncoupled = true
	couplePrompt.Enabled = false
	setPhase(24)
	shakeAll("uncouple")
	-- anyone still in the back two cars jumps forward
	for _, p in inGamePlayers() do
		local _, r = charParts(p)
		if r and r.Position.Z < 66.5 then
			r.CFrame = CFrame.new(1000, -197, 72)
		end
	end
	local t = monsterOf("Thing")
	if t then
		t.huntUntil = nil
		t.stunnedUntil = os.clock() + 20
	end
	local id = round.id
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 7 and round.id == id do
			local dt = RunService.Heartbeat:Wait()
			local k = os.clock() - t0
			local dz = 6 * k * k
			for p, home in rideParts do
				p.CFrame = home - Vector3.new(0, 0, dz)
			end
			if t and t.model.Parent then
				t.feetPos = Vector3.new(t.feetPos.X, t.feetPos.Y, math.min(t.feetPos.Z, 60) - 6 * dt * k * 2)
				t.model:PivotTo(CFrame.new(t.feetPos + Vector3.new(0, t.hip, 0)))
			end
		end
		if t and t.model.Parent then
			t.dead = true
			t.model:Destroy()
		end
	end)
	setObjective("The back cars fall away into the dark... with IT inside. Check the driver's CAB.")
	setMarker(ride.CarC.MapSpot.Position, "CAB")
	spawnMap()
end)
task.spawn(function()
	while true do
		task.wait(0.3)
		if round.active and not round.ending and round.phase >= 13 and os.clock() >= (round.cutsceneUntil or 0) then
			local id = round.id
			if round.phase == 13 and playerIn(Vector3.new(-100, -36, 708), Vector3.new(-30, -8, 880)) then
				setPhase(14)
				round.respawnCF = CFrame.new(-69.5, -31, 712)
				setObjective("The tunnel ahead has COLLAPSED. Start the GENERATOR on the unfinished platform (right) to power the construction LIFT.")
				setMarker(con.Generator.Position, "GENERATOR")
				ensureThing(Vector3.new(-88, -34, 716))
				notifyAll("Something is moving behind the plastic sheets...", Color3.fromRGB(255, 180, 160))
			elseif (round.phase == 14 or round.phase == 15) and playerIn(Vector3.new(-58.5, -19.6, 799), Vector3.new(-49, -10, 853)) then
				setPhase(16)
				round.respawnCF = CFrame.new(-55, -15, 803)
				setObjective("Cross the walkway over the collapse. Jump the gaps - and don't look down.")
				setMarker(con.Walkway.Ladder.Position + Vector3.new(0, 8, 0), "LADDER")
			elseif round.phase == 16 and not round.beamDropped and playerIn(Vector3.new(-58.5, -19.6, 812), Vector3.new(-49, -10, 830)) then
				round.beamDropped = true
				TweenService:Create(fallingBeam, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = beamHome * CFrame.new(-3, -15.5, 0) * CFrame.Angles(0.3, 0, 0.5) }):Play()
				sound(Config.Sounds.Jumpscare, fallingBeam, 1, 0.4)
				shakeAll("quake")
			elseif round.phase == 16 and playerIn(Vector3.new(-100, -36, 843), Vector3.new(-30, -26, 880)) then
				setPhase(17)
				round.respawnCF = CFrame.new(-55, -31, 856)
				cutscene("collapse", 8, {})
				task.delay(8, function()
					if round.id ~= id then
						return
					end
					setObjective("The cave-in sealed everything. The only way on: the SEWER HATCH in the floor.")
					setMarker(con.SewerHatch.Position, "HATCH")
				end)
			elseif round.phase == 19 and playerIn(Vector3.new(-100, -36, 1030), Vector3.new(-40, -20, 1100)) then
				setPhase(20)
				round.respawnCF = CFrame.new(-60, -31, 1066)
				local t = monsterOf("Thing")
				if t then
					-- it stays down in the water... for now
					t.feetPos = mk("SewerThing").Position
					t.waypoints = nil
					t.state = "Patrol"
				end
				cutscene("monitors", 11, {})
				task.delay(11, function()
					if round.id ~= id then
						return
					end
					setObjective("Get the last train running: TRACK SWITCHING panel (south-east) and MAIN POWER panel (north-east). Marsh is HERE.")
					setMarker(ctl.SwitchPanel.Position, "TRACK SWITCH")
					local m = spawnMonster("Marsh", CFrame.new(mk("MarshControl").Position), 22)
					m.idleUntil = os.clock() + 2
				end)
			elseif round.phase == 21 and not round.onPlatform and playerIn(Vector3.new(-80, -36, 1112), Vector3.new(-40, -14, 1230)) then
				round.onPlatform = true
				setPhase(22)
				round.respawnCF = CFrame.new(-50, -27, 1122)
				setObjective("BOARD THE LAST TRAIN - the front car's open door.")
				setMarker(last.BoardPoint.Position, "BOARD")
			end
			-- fell off the walkway onto the rubble: back to the lift top
			if round.phase >= 14 and round.phase <= 17 then
				for _, p in inGamePlayers() do
					local st = roster[p]
					local _, r = charParts(p)
					if r and st and not st.zipping then
						local q = r.Position
						if q.Z > 811 and q.Z < 841 and q.Y > -26 and q.Y < -16.6 then
							r.AssemblyLinearVelocity = Vector3.zero
							r.CFrame = CFrame.new(-55, -15, 803)
							Notify:FireClient(p, "You slipped onto the rubble! Back to the walkway...", Color3.fromRGB(255, 200, 120))
						end
					end
				end
			end
		end
	end
end)

-- CASH: bundles to find on the way (banked in the lobby when you get back) ----------------
local function addCash(player, amount, why)
	player:SetAttribute("RunCash", (player:GetAttribute("RunCash") or 0) + amount)
	Notify:FireClient(player, ("+$%d %s"):format(amount, why or ""), Color3.fromRGB(120, 255, 140))
end
local function spawnCash()
	local pts = marks("PatrolPoint")
	for k = #pts, 2, -1 do
		local j = math.random(k)
		pts[k], pts[j] = pts[j], pts[k]
	end
	for k = 1, math.min(Config.CashBundles or 24, #pts) do
		local pos = pts[k].Position + Vector3.new(math.random(-3, 3), 0.4, math.random(-3, 3))
		local c = itemPart("CashBundle", Vector3.new(1.2, 0.35, 0.7), Color3.fromRGB(90, 200, 100), CFrame.new(pos) * CFrame.Angles(0, math.random() * 6, 0))
		c.Material = Enum.Material.SmoothPlastic
		onTrigger(prompt(c, "Take", "Cash", 0, 8), function(player)
			if roster[player] and c.Parent then
				c:Destroy()
				addCash(player, Config.CashPerBundle or 15, "cash")
			end
		end)
	end
end

-- ESCAPE -------------------------------------------------------------------------------
local function win()
	if round.ending then
		return
	end
	round.ending = true
	local secretFound = workspace:GetAttribute("SecretFound") == true
	if secretFound then
		for _, p in inGamePlayers() do
			addCash(p, 150, "for the SECRET ENDING")
		end
		game:GetService("ServerStorage").SecretWin:Fire(inGamePlayers(), Config.ReturnToLobbyDelay)
	end
	local secs = math.floor(os.clock() - (round.startTime or os.clock()))
	clearMonsters()
	for _, p in inGamePlayers() do
		local _, root = charParts(p)
		if root then
			root.Anchored = true
		end
		Ending:FireClient(p, secs, round.tapes or 0, round.difficulty)
	end
	setObjective("You escaped on the last train.")
	local bonus = (Config.FinishBonus or {})[round.difficulty or "Normal"] or 200
	for _, p in inGamePlayers() do
		addCash(p, bonus, "for escaping (" .. (round.difficulty or "Normal") .. ")")
	end
	local id = round.id
	task.delay(Config.ReturnToLobbyDelay + (secretFound and 26 or 0), function()
		if round.id ~= id then
			return
		end
		local list = inGamePlayers()
		round.resetRound()
		sendToLobby(list, 4) -- chapter 4 complete
		if RunService:IsStudio() then
			-- (Studio) start over
			for _, p in Players:GetPlayers() do
				task.defer(function()
					p:LoadCharacter()
				end)
			end
		end
	end)
end
round.win = win
task.spawn(function()
	while true do
		task.wait(0.25)
		if round.active and not round.ending and round.phase >= 999 then
			for _, p in inGamePlayers() do
				local _, root = charParts(p)
				if root then
					local rel = exitZone.CFrame:PointToObjectSpace(root.Position)
					local h = exitZone.Size / 2
					if math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y + 3 and math.abs(rel.Z) <= h.Z then
						win()
						break
					end
				end
			end
		end
	end
end)

-- STUN GUN -----------------------------------------------------------------------------
local lastStun = {}
StunRemote.OnServerEvent:Connect(function(player, look)
	local st = roster[player]
	local _, root, _, head = charParts(player)
	if not st or not root or st.hidden or round.ending or typeof(look) ~= "Vector3" then
		return
	end
	local charges = player:GetAttribute("StunCharges") or 0
	if charges <= 0 then
		Notify:FireClient(player, "Out of stun charges.")
		return
	end
	if os.clock() - (lastStun[player] or 0) < Config.StunCooldown then
		return
	end
	lastStun[player] = os.clock()
	player:SetAttribute("StunCharges", charges - 1)
	look = look.Magnitude > 0 and look.Unit or root.CFrame.LookVector
	local from = (head or root).Position
	local best, bestD
	for _, m in monsters do
		if not m.dead and not m.inVent then
			local to = m.root.Position - from
			local d = to.Magnitude
			if d <= Config.StunRange and look:Dot(to.Unit) > 0.72 and d < (bestD or math.huge) and workspace:Raycast(from, to, rayParams()) == nil then
				best, bestD = m, d
			end
		end
	end
	if not best then
		Notify:FireClient(player, "Missed!")
		return
	end
	local dur = (Config.StunTime[best.kind] or 4) * D().Stun
	best.stunnedUntil = os.clock() + dur
	best.state = "Search"
	best.searchUntil = os.clock() + dur + 4
	best.lastSeenPos = root.Position
	best.huntUntil = nil
	best.waypoints = nil
	best.model:SetAttribute("Stunned", true)
	task.delay(dur, function()
		if best.model.Parent then
			best.model:SetAttribute("Stunned", nil)
		end
	end)
	Notify:FireClient(player, "Stunned!", Color3.fromRGB(140, 220, 255))
end)
Players.PlayerRemoving:Connect(function(p)
	lastStun[p] = nil
end)

-- ROUND --------------------------------------------------------------------------------
local function resetWorld()
	for door in doorState do
		setDoor(door, false)
	end
	for _, mdl in { e10, e1 } do
		for _, p in mdl:GetChildren() do
			if p:GetAttribute("Home") then
				p.CFrame = p:GetAttribute("Home")
			end
		end
	end
	pryPrompt.Enabled = true
	squeeze.Enabled = true
	placeLobbyMarsh(false)
	liftCage.CFrame = cageBottom
	liftButton.Color = Color3.fromRGB(220, 40, 30)
	fallingBeam.CFrame = beamHome
	genPrompt.Enabled, hatchPrompt.Enabled, switchPrompt.Enabled, powerPrompt.Enabled, boardPrompt.Enabled, couplePrompt.Enabled = true, true, true, true, true, true
	for p, home in gateParts do
		p.CFrame = home
	end
	sew.Gate.GateBlock.CanCollide = true
	for i = 1, 3 do
		local v = sew.Valves:FindFirstChild("Valve" .. i)
		if v then
			v:SetAttribute("Closed", nil)
			if v:GetAttribute("Home") then
				v.CFrame = v:GetAttribute("Home")
			end
			local pr = v:FindFirstChildOfClass("ProximityPrompt")
			if pr then
				pr.Enabled = true
			end
			local l = sew.Valves:FindFirstChild("ValveLight" .. i)
			if l then
				l.Color = Color3.fromRGB(255, 50, 40)
				l.PointLight.Color = l.Color
			end
		end
	end
	for _, n in { "SwitchPanelLight", "PowerPanelLight" } do
		local l = ctl:FindFirstChild(n)
		if l then
			l.Color = Color3.fromRGB(255, 50, 40)
			l.PointLight.Color = l.Color
		end
	end
	for p, home in rideParts do
		p.CFrame = home
	end
	leverPrompt.Enabled = true
	if powerLever:GetAttribute("Home") then
		powerLever.CFrame = powerLever:GetAttribute("Home")
	end
	powerLight.Color = Color3.fromRGB(255, 40, 30)
	local pl = powerLight:FindFirstChildOfClass("PointLight")
	if pl then
		pl.Color = Color3.fromRGB(255, 50, 40)
	end
	for _, spot in hideSpots do
		spot:SetAttribute("Occupant", nil)
	end
end
function round.resetRound()
	workspace:SetAttribute("SecretFound", nil)
	round.id += 1
	clearMonsters()
	itemsFolder:ClearAllChildren()
	resetWorld()
	for _, p in inGamePlayers() do
		local st = roster[p]
		if st and st.hidden then
			unhide(p)
		end
	end
	table.clear(roster)
	round.active = false
	round.ending = false
	round.breached, round.swat, round.pried, round.onCar, round.inLobby, round.squeezed, round.service = false, false, false, false, false, false, false
	round.tapes = 0
	round.stationKey, round.powerOff = false, false
	round.nextTrain, round.trainRunning = nil, false
	round.liftPower, round.beamDropped, round.valves, round.switched, round.ccPower, round.onPlatform, round.boarded, round.uncoupled = false, false, 0, false, false, false, false, false
	round.unlocked = {}
	round.respawnCF = nil
	round.cutsceneUntil = 0
	round.difficulty = nil
	setPhase(0)
	for k, v in { Tapes = 0, Alarm = false, Blackout = false, Difficulty = "", DifficultyChoosing = false, AdminFreeze = nil, MarkerPos = nil, MarkerName = "", StationKey = false, TrackPower = true, Valves = 0, Riding = false } do
		ReplicatedStorage:SetAttribute(k, v)
	end
	setObjective("")
end
function round.applyDifficulty(name, who)
	if not round.choosing then
		return
	end
	round.choosing = false
	round.difficulty = Config.Difficulties[name] and name or Config.DefaultDifficulty
	ReplicatedStorage:SetAttribute("Difficulty", round.difficulty)
	ReplicatedStorage:SetAttribute("DifficultyChoosing", false)
	local d = D()
	for _, p in inGamePlayers() do
		local st = roster[p]
		st.lives = savedLives[p.UserId] or (d.Lives + (p:GetAttribute("Up_ExtraLife") or 0))
		p:SetAttribute("Lives", st.lives)
		p:SetAttribute("StunCharges", d.StunCharges + 2 * (p:GetAttribute("Up_StunPlus") or 0))
		p:SetAttribute("HasStunner", true)
	end
	setPhase(1)
	round.respawnCF = CFrame.new(start.Position)
	round.startTime = os.clock()
	spawnStationKey()
	spawnCash()
	startRaid()
	notifyAll(("Difficulty: %s%s"):format(round.difficulty:upper(), who and (" (picked by " .. who .. ")") or ""), d.Color)
end
ChooseDifficulty.OnServerEvent:Connect(function(player, name)
	if roster[player] and round.choosing and type(name) == "string" and Config.Difficulties[name] then
		round.applyDifficulty(name, player.DisplayName)
	end
end)
local function beginRound()
	round.resetRound()
	round.active = true
	local intro = (RunService:IsStudio() and workspace:GetAttribute("SkipIntro")) and 0 or Config.IntroTime
	ReplicatedStorage:SetAttribute("IntroUntil", workspace:GetServerTimeNow() + intro)
	round.choosing = true
	ReplicatedStorage:SetAttribute("DifficultyChoosing", true)
	ReplicatedStorage:SetAttribute("DifficultyDeadline", workspace:GetServerTimeNow() + intro + Config.DifficultyChooseTime)
	setObjective("Choose a difficulty.")
	local id = round.id
	task.delay(intro + Config.DifficultyChooseTime, function()
		if round.id == id and round.choosing then
			round.applyDifficulty(Config.DefaultDifficulty)
		end
	end)
end

-- JOINING ------------------------------------------------------------------------------
local function joinRound(player)
	if not RunService:IsStudio() and game.PrivateServerId == "" and not player:GetAttribute("RouteFailed") then
		return -- public landing server: PartyRouter moves you to your party's own private server
	end
	while round.ending and player.Parent do
		task.wait(0.5)
	end
	if not player.Parent or roster[player] then
		return
	end
	if not round.active then
		beginRound()
	end
	local d = D()
	-- what you bought in the lobby rides along in the teleport data
	local up = {}
	pcall(function()
		local jd = player:GetJoinData()
		local td = jd and jd.TeleportData
		if type(td) == "table" and type(td.UpgradesByUser) == "table" and type(td.UpgradesByUser[tostring(player.UserId)]) == "table" then
			up = td.UpgradesByUser[tostring(player.UserId)]
		elseif type(td) == "table" and type(td.Upgrades) == "table" then
			up = td.Upgrades
		end
	end)
	if RunService:IsStudio() and workspace:GetAttribute("TestAllUpgrades") then
		up = { flash = 2, flashSkin = "ice", sprinter = true, silent = true, sixth = true, extraLife = 1, stunPlus = 1, skin = "hoodie" }
	end
	local function num(v, max) return math.clamp(tonumber(v) or 0, 0, max) end
	local function str(v) return type(v) == "string" and v:sub(1, 20) or "" end
	player:SetAttribute("Up_Flash", num(up.flash, 2))
	player:SetAttribute("Up_FlashSkin", str(up.flashSkin))
	player:SetAttribute("Up_Sprinter", up.sprinter == true)
	player:SetAttribute("Up_Silent", up.silent == true)
	player:SetAttribute("Up_Sixth", up.sixth == true)
	player:SetAttribute("Up_ExtraLife", num(up.extraLife, 6))
	player:SetAttribute("Up_StunPlus", num(up.stunPlus, 2))
	player:SetAttribute("Up_Skin", str(up.skin))
	player:SetAttribute("RunCash", player:GetAttribute("RunCash") or 0)
	-- outfit skin bought in the lobby (borrowed from the game's own characters)
	local skinFrom = ({ agent = "Guard", director = "Marsh", guest = "B01" })[player:GetAttribute("Up_Skin") or ""]
	local srcModel = skinFrom and ServerStorage.Monsters:FindFirstChild(skinFrom)
	local ch = player.Character
	if srcModel and ch then
		for _, cls in { "Shirt", "Pants" } do
			local from = srcModel:FindFirstChildOfClass(cls)
			if from then
				local old = ch:FindFirstChildOfClass(cls)
				if old then
					old:Destroy()
				end
				from:Clone().Parent = ch
			end
		end
	end
	roster[player] = { lives = savedLives[player.UserId] or (d.Lives + (player:GetAttribute("Up_ExtraLife") or 0)), protectedUntil = os.clock() + 4 }
	-- the Infinite Lives game pass (bought in chapter 1) works in every chapter
	task.spawn(function()
		local ok, owns = pcall(function()
			return game:GetService("MarketplaceService"):UserOwnsGamePassAsync(player.UserId, 2076033249)
		end)
		if ok and owns and roster[player] then
			roster[player].infinite = true
			player:SetAttribute("InfiniteLives", true)
		end
	end)
	player:SetAttribute("InGame", true)
	player:SetAttribute("Lives", roster[player].lives)
	if round.difficulty then
		player:SetAttribute("StunCharges", player:GetAttribute("StunCharges") or d.StunCharges)
		player:SetAttribute("HasStunner", true)
	end
	local char = player.Character
	if char then
		char:PivotTo((round.respawnCF or start.CFrame) + Vector3.new(math.random(-4, 4), 3, 0))
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Died:Connect(function()
				if roster[player] then
					local st = roster[player]
					if st.hidden then
						unhide(player)
					end
					roster[player] = nil
				end
			end)
		end
	end
end
local function onPlayer(p)
	p.CharacterAdded:Connect(function()
		task.defer(function()
			if not roster[p] then
				joinRound(p)
			end
		end)
	end)
	if p.Character then
		task.defer(joinRound, p)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end
Players.PlayerRemoving:Connect(function(p)
	if roster[p] then
		local st = roster[p]
		if st.hidden then
			unhide(p)
		end
		roster[p] = nil
	end
	savedLives[p.UserId] = nil
	task.defer(function()
		if round.active and not round.ending and #inGamePlayers() == 0 then
			round.resetRound()
		end
	end)
end)

-- ADMIN (owner only, checked here) --------------------------------------------------------
local function isAdmin(player)
	return RunService:IsStudio() or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
end
AdminRemote.OnServerEvent:Connect(function(player, cmd, value)
	if not isAdmin(player) or type(cmd) ~= "string" then
		return
	end
	local function say(t)
		Notify:FireClient(player, "[ADMIN] " .. t, Color3.fromRGB(255, 220, 90))
	end
	if cmd == "god" then
		player:SetAttribute("AdminGod", value == true or nil)
		say(value and "God mode ON." or "God mode OFF.")
	elseif cmd == "freeze" then
		ReplicatedStorage:SetAttribute("AdminFreeze", value == true or nil)
		say(value and "Monsters FROZEN." or "Monsters unfrozen.")
	elseif cmd == "refill" then
		player:SetAttribute("HasStunner", true)
		player:SetAttribute("StunCharges", Config.StunMaxCharges)
		say("Stun gun refilled.")
	elseif cmd == "clear" then
		for _, m in monsters do
			if m.kind == "Guard" then
				m.dead = true
				m.model:Destroy()
			end
		end
		say("Guards removed.")
	elseif cmd == "skip" then
		local _, r = charParts(player)
		if round.phase == 1 then
			if r then r.CFrame = CFrame.new(-6, F12 + 3, -20) end
		elseif round.phase == 2 then
			openDoor(DOORS.StairDoor12)
			if r then r.CFrame = CFrame.new(36, F12 + 3, 5.5) end
		elseif round.phase == 3 then
			round.swat = true
			openDoor(DOORS.StairDoor10)
			if r then r.CFrame = CFrame.new(24, F10 + 3, 0) end
		elseif round.phase == 4 then
			round.pried = true
			pryPrompt.Enabled = false
			slideDoors(e10, 1.5)
			if r then r.CFrame = CFrame.new(-1.5, 12.5, 5.5) end
		elseif round.phase == 5 then
			openDoor(DOORS.BackDoor)
			if r then r.CFrame = CFrame.new(-22, 3, 38) end
		elseif round.phase == 6 then
			if r then r.CFrame = CFrame.new(-45, -11, 84) end
		elseif round.phase == 7 then
			round.stationKey = true
			ReplicatedStorage:SetAttribute("StationKey", true)
			openDoor(serviceGate)
			setPhase(8)
			if r then r.CFrame = CFrame.new(-45, -11, 104) end
		elseif round.phase == 8 or round.phase == 9 then
			if r then r.CFrame = CFrame.new(-32, -27, 230) end
		elseif round.phase == 10 then
			if r then r.CFrame = CFrame.new(-69.5, -31, 260) end
		elseif round.phase == 11 then
			if r then r.CFrame = CFrame.new(-69.5, -31, 420) end
		elseif round.phase == 12 then
			if r then r.CFrame = CFrame.new(-54, -31, 482) end
		elseif round.phase == 13 then
			if r then r.CFrame = CFrame.new(-69.5, -31, 712) end
		elseif round.phase == 14 or round.phase == 15 then
			round.liftPower = true
			if r then r.CFrame = CFrame.new(-55, -15, 803) end
		elseif round.phase == 16 then
			if r then r.CFrame = CFrame.new(-55, -31, 856) end
		elseif round.phase == 17 or round.phase == 18 then
			if round.phase == 17 then
				setPhase(18)
			end
			round.valves = 3
			for p, home in gateParts do
				p.CFrame = home + Vector3.new(0, 11.5, 0)
			end
			sew.Gate.GateBlock.CanCollide = false
			setPhase(19)
			if r then r.CFrame = CFrame.new(-60, -31, 1066) end
		elseif round.phase == 19 or round.phase == 20 then
			if round.phase == 19 then
				setPhase(20)
			end
			round.switched, round.ccPower = true, true
			controlDone()
		elseif round.phase == 21 or round.phase == 22 then
			if r then r.CFrame = CFrame.new(-60, -27, 1204) end
		elseif round.phase == 23 then
			if r then r.CFrame = CFrame.new(1000, -197, 70) end
		elseif round.phase >= 24 then
			win()
		end
		say("Skipped ahead (phase " .. round.phase .. ").")
	elseif cmd == "cash" then
		addCash(player, 500, "(admin)")
	elseif cmd == "tp" and typeof(value) == "Vector3" then
		local _, r = charParts(player)
		if r then
			r.CFrame = CFrame.new(value)
		end
	elseif cmd == "win" then
		win()
	end
end)

-- Studio-only test hook
if RunService:IsStudio() then
	local dbg = Instance.new("BindableFunction")
	dbg.Name = "Ch4Debug"
	dbg.Parent = ServerStorage
	dbg.OnInvoke = function(cmd, arg)
		if cmd == "state" then
			local list = {}
			for _, m in monsters do
				table.insert(list, ("%s %s %s"):format(m.kind, m.state, tostring(m.feetPos)))
			end
			return ("phase=%d breached=%s swat=%s pried=%s lobby=%s | %s"):format(round.phase, tostring(round.breached), tostring(round.swat), tostring(round.pried), tostring(round.inLobby), table.concat(list, "; "))
		elseif cmd == "phase" then
			-- (testing) jump to a phase with the flags that come before it
			local n = tonumber(arg) or round.phase
			round.breached, round.swat, round.pried, round.onCar, round.inLobby = true, true, true, true, true
			if n >= 8 then round.stationKey = true end
			if n >= 10 then round.powerOff = true end
			if n >= 15 then round.liftPower = true end
			setPhase(n)
			return "phase " .. n
		elseif cmd == "difficulty" then
			round.applyDifficulty(arg or "Normal", "debug")
		elseif cmd == "admin" then
			AdminRemote:FireAllClients() -- no-op
		end
	end
end
round.resetRound()
