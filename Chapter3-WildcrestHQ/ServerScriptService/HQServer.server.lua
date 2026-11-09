-- CHAPTER 3: WILDCREST HQ - server
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
local level = workspace:WaitForChild("HQ")
local exterior = workspace:WaitForChild("Exterior")
local start = exterior:WaitForChild("Start")
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
	return y > 60 and 4 or (y > 40 and 3 or (y > 19 and 2 or 1))
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
local patrolByFloor = { {}, {}, {}, {} }
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
	s.SoundId = kind == "B01" and Config.Sounds.Growl or ""
	s.Volume = 2
	s.PlaybackSpeed = 0.8
	s.RollOffMaxDistance = 110
	s.Parent = m.root
	m.growl = kind == "B01" and s or nil
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
	if math.abs(root.Position.Y - m.feetPos.Y) > 14 then
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
		m.feetPos = Vector3.new(best.Position.X, floorOf(best.Position.Y) == 1 and 0 or ({ 0, 21, 42, 63 })[floorOf(best.Position.Y)], best.Position.Z)
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
	if m.kind == "B01" then
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
		options:SetTeleportData({ Completed = completed, Earned = math.clamp(p:GetAttribute("RunCash") or 0, 0, Config.MaxEarnedPerRun or 2000), From = 3, Secret = p:GetAttribute("SecretEnding") and 3 or nil })
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

-- ITEMS --------------------------------------------------------------------------------
local function addEvidence(player, label)
	round.evidence += 1
	ReplicatedStorage:SetAttribute("Evidence", round.evidence)
	notifyAll(("%s found evidence: %s (%d/%d)"):format(player.DisplayName, label, math.min(round.evidence, Config.EvidenceNeeded), Config.EvidenceNeeded), Color3.fromRGB(140, 220, 255))
	if round.evidence >= Config.EvidenceNeeded and round.phase == 1 then
		setPhase(2)
		pa("Someone is going through my files. Find them.")
		setObjective(round.keycard1 and "Enough evidence! Now free the test subjects in CONTAINMENT (ground floor, north-east)."
			or "Enough evidence! Get the guard keycard from SECURITY, then free the test subjects in CONTAINMENT.")
	end
end
local evidenceNames = { "Payroll for 'Project B'", "Subject intake form", "Autopsy photos", "Shipping manifest (B-02, B-03...)", "Bribery ledger page",
	"FBI contract", "Surgery schedule", "Zoo 'incident' cover-up memo", "Visitor list - missing guests", "Lab footage USB", "Burn order", "Signed NDA (dead employee)",
	"Gene sequence printout", "Board meeting minutes" }
local function spawnEvidence(pos, label)
	local e = itemPart("Evidence", Vector3.new(1.2, 0.2, 1.6), Color3.fromRGB(120, 200, 255), CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.random() * 6, 0))
	e.Material = Enum.Material.SmoothPlastic
	e.Color = Color3.fromRGB(240, 235, 220)
	onTrigger(prompt(e, "Take", "Evidence: " .. label, 0.4, 8), function(player)
		if roster[player] and e.Parent then
			e:Destroy()
			addEvidence(player, label)
		end
	end)
	return e
end
function round.spawnItems()
	itemsFolder:ClearAllChildren()
	-- loose evidence
	local spots = marks("EvidenceSpot")
	for i = #spots, 2, -1 do
		local j = math.random(i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	local names = table.clone(evidenceNames)
	for i = 1, math.min(Config.EvidenceSpawned, #spots) do
		spawnEvidence(spots[i].Position, names[(i - 1) % #names + 1])
	end
	-- the guard keycard (level 1)
	local ks = marks("KeycardSpot")[1]
	if ks then
		local k = itemPart("Keycard", Vector3.new(0.9, 0.08, 1.4), Color3.fromRGB(60, 150, 255), CFrame.new(ks.Position) * CFrame.Angles(0, 0.4, 0))
		onTrigger(prompt(k, "Take", "Guard Keycard (Level 1)", 0.3), function(player)
			if roster[player] and k.Parent then
				k:Destroy()
				round.keycard1 = true
				ReplicatedStorage:SetAttribute("Keycard1", true)
				notifyAll(player.DisplayName .. " took the GUARD KEYCARD (Level 1). Swipe it at the Containment door.", Color3.fromRGB(120, 190, 255))
				if round.phase == 2 then
					setObjective("Free the test subjects in CONTAINMENT (ground floor, north-east).")
				end
			end
		end)
	end
	-- the safe code, on a sticky note
	round.safeCode = tostring(math.random(1000, 9999))
	local cs = marks("CodeNoteSpot")
	local spot = cs[math.random(#cs)]
	if spot then
		local n = itemPart("CodeNote", Vector3.new(1, 0.05, 1), Color3.fromRGB(255, 240, 90), CFrame.new(spot.Position) * CFrame.Angles(0, math.random() * 6, 0))
		n.Material = Enum.Material.SmoothPlastic
		onTrigger(prompt(n, "Read", "Sticky Note", 0), function(player)
			ShowNote:FireClient(player, "STICKY NOTE", ("Mr. Marsh,\nyour new safe combination is:\n\n%s\n\nPlease memorise it and DESTROY this note.\n- R."):format(round.safeCode))
		end)
	end
	-- stun cartridges
	local function spawnCartridge(sp)
		local id = round.id
		local c = itemPart("StunCartridge", Vector3.new(0.6, 0.6, 1), Color3.fromRGB(120, 220, 255), CFrame.new(sp.Position))
		onTrigger(prompt(c, "Take", "Stun Cartridge", 0), function(player)
			if not roster[player] or not c.Parent then
				return
			end
			local n = player:GetAttribute("StunCharges") or 0
			if n >= Config.StunMaxCharges then
				Notify:FireClient(player, "Stun gun is full.")
				return
			end
			c:Destroy()
			player:SetAttribute("StunCharges", n + 1)
			task.delay(Config.CartridgeRespawn, function()
				if round.id == id and round.active then
					spawnCartridge(sp)
				end
			end)
		end)
	end
	for _, sp in marks("CartridgeSpot") do
		spawnCartridge(sp)
	end
	-- lore tapes
	for i, sp in marks("TapeSpot") do
		local t = itemPart("Tape", Vector3.new(1, 0.6, 0.7), Color3.fromRGB(255, 150, 60), CFrame.new(sp.Position))
		t.Material = Enum.Material.SmoothPlastic
		t.Color = Color3.fromRGB(40, 40, 44)
		onTrigger(prompt(t, "Listen", "Recorder", 0.5), function(player)
			if not roster[player] or not t.Parent then
				return
			end
			t:Destroy()
			round.tapes += 1
			ReplicatedStorage:SetAttribute("Tapes", round.tapes)
			ShowNote:FireClient(player, ("RECORDING %d/6"):format(round.tapes), sp:GetAttribute("Text"))
			notifyAll(("%s found a recording (%d/6 tapes)."):format(player.DisplayName, round.tapes), Color3.fromRGB(255, 190, 120))
		end)
	end
end

-- STATIONS -----------------------------------------------------------------------------
-- card readers (swipe mini-game)
for _, reader in CollectionService:GetTagged("CardReader") do
	local door = doorByName(reader:GetAttribute("Door"))
	local level2 = reader:GetAttribute("Level") == 2
	local pr = prompt(reader, "Swipe Card", level2 and "Server Room (Level 2)" or "Containment (Level 1)", 0, 7)
	onTrigger(pr, function(player)
		if not roster[player] or round.unlocked[door.Name] then
			return
		end
		if level2 and not round.keycard2 then
			Notify:FireClient(player, "ACCESS DENIED - Level 2 card needed. Marsh keeps his in the penthouse safe (floor 2).", Color3.fromRGB(255, 90, 80))
			return
		end
		if not level2 and not round.keycard1 then
			Notify:FireClient(player, "ACCESS DENIED - you need the guard keycard (Security, ground floor).", Color3.fromRGB(255, 90, 80))
			return
		end
		startMinigame(player, "swipe", {}, 0.8, function(ok)
			if ok then
				round.unlocked[door.Name] = true
				setDoor(door, true)
				local light = reader:FindFirstChild("ReaderLight")
				if light then
					light.Color = Color3.fromRGB(60, 255, 90)
				end
				notifyAll("ACCESS GRANTED - " .. (level2 and "Server Room" or "Containment") .. " is open.", Color3.fromRGB(120, 255, 140))
			else
				Notify:FireClient(player, "Swipe failed. Try again - smooth and steady.")
			end
		end)
	end)
end
-- locked filing cabinets (lockpick)
for _, cab in CollectionService:GetTagged("LockedCabinet") do
	local pr = prompt(cab, "Pick Lock", "Locked Cabinet", 0, 7)
	onTrigger(pr, function(player)
		if not roster[player] or cab:GetAttribute("Opened") then
			return
		end
		startMinigame(player, "lockpick", { pins = 3 }, 2.5, function(ok)
			if ok and not cab:GetAttribute("Opened") then
				cab:SetAttribute("Opened", true)
				cab.Color = Color3.fromRGB(60, 70, 50)
				pr.Enabled = false
				addEvidence(player, "Locked files")
			elseif not ok then
				Notify:FireClient(player, "The pick slipped. Try again.")
			end
		end)
	end)
end
-- Marsh's safe (keypad): evidence + the Level 2 keycard
for _, safe in CollectionService:GetTagged("KeypadSafe") do
	local pr = prompt(safe, "Open Safe", "Marsh's Safe", 0, 7)
	onTrigger(pr, function(player)
		if not roster[player] or round.keycard2 then
			return
		end
		startMinigame(player, "keypad", { length = 4 }, 1.5, function(ok, code)
			if ok and tostring(code) == round.safeCode then
				round.keycard2 = true
				ReplicatedStorage:SetAttribute("Keycard2", true)
				pr.Enabled = false
				safe.Color = Color3.fromRGB(40, 42, 46)
				addEvidence(player, "Marsh's private ledger")
				notifyAll(player.DisplayName .. " cracked Marsh's safe: LEVEL 2 KEYCARD!", Color3.fromRGB(255, 220, 90))
				if round.phase == 3 then
					setObjective("Use the LEVEL 2 card at the SERVER ROOM (ground floor, by the stairs) and upload the evidence.")
				end
			else
				Notify:FireClient(player, ok and "WRONG CODE. Somebody wrote it down somewhere..." or "You backed away from the safe.", Color3.fromRGB(255, 120, 90))
			end
		end)
	end)
end
-- subject cells (wires)
local releaseB01 -- (below)
for _, console in CollectionService:GetTagged("CellConsole") do
	local cell = console.Parent
	local pr = prompt(console, "Release Lock", "Cell " .. tostring(console:GetAttribute("Cell")), 0, 7)
	onTrigger(pr, function(player)
		if not roster[player] or console:GetAttribute("Freed") then
			return
		end
		if round.phase < 2 then
			Notify:FireClient(player, ("Get the evidence first (%d/%d) - these people are your proof."):format(round.evidence, Config.EvidenceNeeded))
			return
		end
		startMinigame(player, "wires", { count = 4 }, 3, function(ok)
			if not ok then
				Notify:FireClient(player, "Wrong wire - the lock reset.")
				return
			end
			console:SetAttribute("Freed", true)
			pr.Enabled = false
			local door = cell:FindFirstChild("CellDoor")
			if door then
				TweenService:Create(door, TweenInfo.new(1), { CFrame = door.CFrame + Vector3.new(0, 9.5, 0) }):Play()
			end
			local scr = cell:FindFirstChild("ConsoleScreen")
			if scr then
				scr.Color = Color3.fromRGB(70, 255, 110)
			end
			-- the subject staggers out and flees
			local subj, head = cell:FindFirstChild("Subject"), cell:FindFirstChild("SubjectHead")
			task.delay(1.2, function()
				for _, part in { subj, head } do
					if part then
						TweenService:Create(part, TweenInfo.new(3), { CFrame = part.CFrame + Vector3.new(0, 0, 30), Transparency = 1 }):Play()
					end
				end
			end)
			round.cellsFreed += 1
			ReplicatedStorage:SetAttribute("CellsFreed", round.cellsFreed)
			notifyAll(("Subject freed (%d/3). They run for the exit..."):format(round.cellsFreed), Color3.fromRGB(140, 255, 160))
			if round.cellsFreed >= 3 then
				releaseB01()
			end
		end)
	end)
end
-- server upload (hack)
for _, term in CollectionService:GetTagged("ServerTerminal") do
	local pr = prompt(term, "Upload Evidence", "Server Terminal", 0, 8)
	onTrigger(pr, function(player)
		if not roster[player] or round.uploaded then
			return
		end
		if round.phase < 3 then
			Notify:FireClient(player, "Free the test subjects first - you need them as witnesses.")
			return
		end
		startMinigame(player, "hack", { rounds = 3 }, 5, function(ok)
			if not ok then
				Notify:FireClient(player, "INTRUSION DETECTED - the firewall kicked you out. Try again.", Color3.fromRGB(255, 90, 80))
				for _, m in monsters do
					if m.kind == "Guard" and not m.dead then
						m.state = "Search"
						m.lastSeenPos = term.Position
						m.searchUntil = os.clock() + 10
					end
				end
				return
			end
			round.uploaded = true
			pr.Enabled = false
			setPhase(4)
			round.respawnCF = CFrame.new(28, 43, 0)
			notifyAll("UPLOAD COMPLETE. The files are on the uplink server.", Color3.fromRGB(120, 255, 140))
			pa("You think a server can save you? Every signal out of here goes through MY transmitter.")
			setObjective("Boot the TRANSMITTER in UPLINK CONTROL (floor 3, north-east).")
		end)
	end)
end

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

-- B-01 BREAKS OUT
function releaseB01()
	if round.released then
		return
	end
	round.released = true
	setPhase(3)
	ReplicatedStorage:SetAttribute("Alarm", true)
	local cellModel = level.Rooms.Containment.Cells:FindFirstChild("B01Cell")
	local glass = cellModel and cellModel:FindFirstChild("B01Glass")
	local sp = marks("B01Spawn")[1]
	cutscene("release", 12.5, { glass = glass and glass.Position, spawn = sp and sp.Position })
	task.delay(3.2, function()
		if glass then
			for _ = 1, 18 do
				local shard = Instance.new("Part")
				shard.Size = Vector3.new(math.random() + 0.3, math.random() + 0.3, 0.1)
				shard.Color = glass.Color
				shard.Material = Enum.Material.Glass
				shard.Transparency = 0.4
				shard.CanCollide = false
				shard.CFrame = glass.CFrame * CFrame.new(math.random(-6, 6), math.random(-5, 5), 0)
				shard.AssemblyLinearVelocity = Vector3.new(math.random(-12, 12), math.random(2, 12), math.random(8, 24))
				shard.Parent = itemsFolder
				Debris:AddItem(shard, 4)
			end
			glass.Transparency = 1
			glass.CanCollide = false
		end
	end)
	local id = round.id
	task.delay(3.4, function()
		if round.id ~= id then
			return
		end
		local b = spawnMonster("B01", CFrame.new(sp.Position), 1)
		b.yaw = 0
		b.idleUntil = os.clock() + 6
	end)
	-- then Marsh shows himself
	task.delay(12.7, function()
		if round.id ~= id then
			return
		end
		local ms = marks("MarshSpawn")
		local spot
		for _, m in ms do
			if m.Position.Y > 19 then
				spot = m
			end
		end
		spot = spot or ms[1]
		local marsh = spawnMonster("Marsh", CFrame.new(spot.Position), 2)
		marsh.idleUntil = os.clock() + 14
		cutscene("marsh", 13, { pos = spot.Position })
		task.delay(13.2, function()
			if round.id ~= id then
				return
			end
			-- CHASE 1: it already has your scent
			forceHunt(monsterOf("B01"), 12)
			for _, p in inGamePlayers() do
				Notify:FireClient(p, "B-01 IS HUNTING YOU - RUN!", Color3.fromRGB(255, 60, 50))
			end
			round.respawnCF = CFrame.new(0, 1, 60)
			setObjective(round.keycard2 and "Use the LEVEL 2 card at the SERVER ROOM (ground floor, by the stairs) and upload the evidence."
				or "Get Marsh's LEVEL 2 KEYCARD from his penthouse safe (floor 2, north-east). The code is written down somewhere...")
		end)
	end)
end

-- TRANSMITTER (memory sequence) -> blackout -> generator
for _, panel in CollectionService:GetTagged("TransmitterPanel") do
	local pr = prompt(panel, "Boot Transmitter", "Uplink Transmitter", 0, 8)
	onTrigger(pr, function(player)
		if not roster[player] or round.transmitter then
			return
		end
		if round.phase < 4 then
			Notify:FireClient(player, "Nothing to send yet - upload the evidence from the SERVER ROOM first.")
			return
		end
		if round.blackout then
			Notify:FireClient(player, "NO POWER. Restart the generator (floor 3, small room south of the stairs).")
			return
		end
		startMinigame(player, "simon", { length = 5 }, 4, function(ok)
			if not ok then
				Notify:FireClient(player, "Boot sequence failed. Watch the lights and try again.")
				return
			end
			if round.blackoutDone then
				round.transmitter = true
				pr.Enabled = false
				setPhase(5)
				round.respawnCF = CFrame.new(20, 64, -50)
				notifyAll("TRANSMITTER ONLINE.", Color3.fromRGB(120, 255, 140))
				setObjective("Get to the ROOF (stairs, floor 3). ALIGN THE DISH, then START THE BROADCAST.")
				pa("Fine. Come up to the roof. I'll be waiting.")
				return
			end
			-- Marsh pulls the power (cutscene: Security room breaker -> lights die one by one)
			round.blackout = true
			cutscene("blackout", 11, {})
			local bid = round.id
			task.delay(7.6, function()
				if round.id == bid and round.blackout then
					ReplicatedStorage:SetAttribute("Blackout", true)
				end
			end)
			task.delay(11, function()
				if round.id ~= bid or not round.blackout then
					return
				end
				notifyAll("THE POWER IS OUT. Restart the GENERATOR (floor 3, small room south of the stairs)!", Color3.fromRGB(255, 120, 60))
				setObjective("BLACKOUT! Restart the GENERATOR (floor 3, south of the stairs), then boot the transmitter again.")
				-- CHASE 2: in the dark it comes for you
				local target = (player.Parent and roster[player]) and player or nil
				local b = monsterOf("B01")
				local vt = target or nearestPlayerTo(b and b.feetPos or Vector3.zero)
				if b and vt and not b.inVent then
					ventTravel(b, vt)
					task.delay(4.5, function()
						if round.id == bid then
							forceHunt(b, 10, target)
						end
					end)
				end
				forceHunt(monsterOf("Marsh"), 14, target)
			end)
		end)
	end)
end
for _, gen in CollectionService:GetTagged("GeneratorStation") do
	local pr = prompt(gen, "Restart Generator", "Backup Generator", 0, 8)
	onTrigger(pr, function(player)
		if not roster[player] then
			return
		end
		if not round.blackout then
			Notify:FireClient(player, "The generator is running fine.")
			return
		end
		startMinigame(player, "generator", { pulls = 4 }, 3, function(ok)
			if not ok then
				Notify:FireClient(player, "The engine coughed and died. Pull again - in rhythm!")
				return
			end
			round.blackout = false
			round.blackoutDone = true
			ReplicatedStorage:SetAttribute("Blackout", false)
			notifyAll("POWER RESTORED. Boot the transmitter again (Uplink Control).", Color3.fromRGB(120, 255, 140))
			setObjective("Power's back. BOOT THE TRANSMITTER again (Uplink Control, floor 3).")
		end)
	end)
end

-- ROOF: dish + broadcast
local roof = level:WaitForChild("Roof")
for _, ctl in CollectionService:GetTagged("DishControl") do
	local pr = prompt(ctl, "Align Dish", "Satellite Dish", 0, 8)
	onTrigger(pr, function(player)
		if not roster[player] or round.dish then
			return
		end
		if round.phase < 5 then
			Notify:FireClient(player, "The transmitter is offline - the dish has nothing to send.")
			return
		end
		startMinigame(player, "dish", {}, 3, function(ok)
			if not ok then
				Notify:FireClient(player, "Lost the signal. Try again.")
				return
			end
			round.dish = true
			pr.Enabled = false
			local bowl = CollectionService:GetTagged("DishBowl")[1]
			if bowl then
				TweenService:Create(bowl, TweenInfo.new(2), { CFrame = CFrame.new(bowl.Position) * CFrame.Angles(0, math.rad(160), math.rad(-35)) }):Play()
			end
			notifyAll("DISH ALIGNED. Start the broadcast at the console under the tower!", Color3.fromRGB(120, 255, 140))
			setObjective("START THE BROADCAST at the console under the radio tower - and stay close to it!")
		end)
	end)
end
local function startBroadcast()
	round.broadcasting = true
	ReplicatedStorage:SetAttribute("Broadcast", 0)
	local console = CollectionService:GetTagged("BroadcastConsole")[1]
	pa("Broadcasting? To who? Nobody believes a fired employee.")
	-- everyone comes up to the roof
	local b = monsterOf("B01")
	local list = inGamePlayers()
	if b and #list > 0 then
		ventTravel(b, list[1])
	end
	local marsh = monsterOf("Marsh")
	local arrive = marks("RoofArrive")[1]
	if marsh and arrive and floorOf(marsh.feetPos.Y) ~= 4 then
		marsh.feetPos = arrive.Position
		marsh.waypoints = nil
		marsh.idleUntil = os.clock() + 3
	end
	local id = round.id
	local progress = 0
	task.spawn(function()
		while round.id == id and round.broadcasting do
			task.wait(0.25)
			local near = false
			for _, p in inGamePlayers() do
				local _, r = charParts(p)
				if r and (r.Position - console.Position).Magnitude < Config.BroadcastRange then
					near = true
				end
			end
			if near and os.clock() >= (round.cutsceneUntil or 0) then
				progress = math.min(100, progress + 25 / Config.BroadcastTime)
			end
			ReplicatedStorage:SetAttribute("Broadcast", math.floor(progress))
			ReplicatedStorage:SetAttribute("BroadcastStalled", not near)
			if progress >= 96 then
				round.broadcasting = false
				round.cutSignal()
			end
		end
	end)
end
for _, bc in CollectionService:GetTagged("BroadcastConsole") do
	local pr = prompt(bc, "Start Broadcast", "Broadcast Console", 1.5, 8)
	onTrigger(pr, function(player)
		if not roster[player] or round.broadcasting or round.signalCut then
			return
		end
		if not round.dish then
			Notify:FireClient(player, "The dish isn't aligned yet (control box next to the dish).")
			return
		end
		pr.Enabled = false
		notifyAll("BROADCAST STARTED - stay near the console until it reaches 100%!", Color3.fromRGB(255, 220, 90))
		setObjective("BROADCASTING... stay near the console! (B-01 and Marsh are coming)")
		startBroadcast()
	end)
end
function round.cutSignal()
	if round.signalCut then
		return
	end
	round.signalCut = true
	setPhase(6)
	local console = CollectionService:GetTagged("BroadcastConsole")[1]
	local marsh = monsterOf("Marsh")
	if marsh and console then
		marsh.feetPos = console.Position + Vector3.new(4, -2, -4)
		marsh.waypoints = nil
	end
	cutscene("cut", 15, { console = console and console.Position })
	local id = round.id
	task.delay(15, function()
		if round.id ~= id then
			return
		end
		ReplicatedStorage:SetAttribute("Broadcast", 96)
		ReplicatedStorage:SetAttribute("SignalCut", true)
		setObjective("THE SIGNAL IS DEAD. ESCAPE! Take the ZIPLINE (south edge of the roof) to the gate!")
		notifyAll("RUN FOR THE ZIPLINE (south edge of the roof)!", Color3.fromRGB(255, 70, 60))
		-- CHASE 3: everything comes for you
		for _, m in monsters do
			if not m.dead then
				m.cfg.Sense = 18
				if m.kind ~= "Guard" then
					forceHunt(m, 22)
				end
			end
		end
		round.respawnCF = CFrame.new(40, 64, 60)
	end)
end

-- ZIPLINE
for _, zs in CollectionService:GetTagged("ZiplineStart") do
	local pr = prompt(zs, "Ride Zipline", "Zipline to the gate", 0.3, 9)
	local from, to = zs:GetAttribute("From"), zs:GetAttribute("To")
	onTrigger(pr, function(player)
		local st = roster[player]
		if not st or st.zipping then
			return
		end
		if not round.signalCut then
			Notify:FireClient(player, "Not yet - finish the broadcast first.")
			return
		end
		local _, root = charParts(player)
		if not root then
			return
		end
		st.zipping = true
		root.Anchored = true
		ZipRemote:FireClient(player, from, to, 6)
		local t0 = os.clock()
		while os.clock() - t0 < 6 and root.Parent do
			local k = (os.clock() - t0) / 6
			local pos = from:Lerp(to, k) - Vector3.new(0, 4, 0)
			root.CFrame = CFrame.lookAt(pos, pos + (to - from).Unit)
			RunService.Heartbeat:Wait()
		end
		if root.Parent then
			root.CFrame = CFrame.new(to + Vector3.new(0, 0, 6))
			root.Anchored = false
		end
		st.zipping = false
		st.protectedUntil = os.clock() + 2
		Notify:FireClient(player, "Down! Get through the GATE!", Color3.fromRGB(255, 220, 90))
		-- B-01 isn't done with you
		local b = monsterOf("B01")
		if b and not b.inVent and not round.finalVent then
			round.finalVent = true
			b.inVent = true
			b.model:PivotTo(CFrame.new(0, -500, 0))
			task.delay(1.5, function()
				b.feetPos = Vector3.new(-30, 0, 150)
				b.inVent = false
				forceHunt(b, 16, player)
				for _, p in inGamePlayers() do
					VentRemote:FireClient(p, b.feetPos, "out")
				end
			end)
		end
	end)
end

-- CASH: bundles to find (banked in the lobby when you get back) ----------------------------
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
	for k = 1, math.min(Config.CashBundles or 20, #pts) do
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
	setObjective("You escaped Wildcrest HQ.")
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
		sendToLobby(list, 3)
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
task.spawn(function()
	while true do
		task.wait(0.25)
		if round.active and not round.ending and round.signalCut then
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
		Notify:FireClient(player, "Out of stun charges. Find cartridges (Armory, Barracks, Security).")
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
	for _, r in CollectionService:GetTagged("CardReader") do
		local l = r:FindFirstChild("ReaderLight")
		if l then
			l.Color = Color3.fromRGB(255, 50, 40)
		end
	end
	for _, c in CollectionService:GetTagged("CellConsole") do
		c:SetAttribute("Freed", nil)
		local pr = c:FindFirstChildOfClass("ProximityPrompt")
		if pr then
			pr.Enabled = true
		end
		local cell = c.Parent
		local door = cell:FindFirstChild("CellDoor")
		if door then
			door:SetAttribute("Home", door:GetAttribute("Home") or door.CFrame)
			door.CFrame = door:GetAttribute("Home")
		end
		for _, n in { "Subject", "SubjectHead" } do
			local part = cell:FindFirstChild(n)
			if part then
				part:SetAttribute("Home", part:GetAttribute("Home") or part.CFrame)
				part.CFrame = part:GetAttribute("Home")
				part.Transparency = 0
			end
		end
		local scr = cell:FindFirstChild("ConsoleScreen")
		if scr then
			scr.Color = Color3.fromRGB(255, 70, 60)
		end
	end
	local cellModel = level.Rooms.Containment.Cells:FindFirstChild("B01Cell")
	local glass = cellModel and cellModel:FindFirstChild("B01Glass")
	if glass then
		glass.Transparency = 0.55
		glass.CanCollide = true
	end
	for _, tag in { "LockedCabinet", "KeypadSafe", "ServerTerminal", "TransmitterPanel", "DishControl", "BroadcastConsole" } do
		for _, s in CollectionService:GetTagged(tag) do
			s:SetAttribute("Opened", nil)
			local pr = s:FindFirstChildOfClass("ProximityPrompt")
			if pr then
				pr.Enabled = true
			end
		end
	end
	for _, s in CollectionService:GetTagged("LockedCabinet") do
		s.Color = Color3.fromRGB(80, 90, 60)
	end
	for _, s in CollectionService:GetTagged("KeypadSafe") do
		s.Color = Color3.fromRGB(70, 72, 76)
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
	round.evidence, round.tapes, round.cellsFreed = 0, 0, 0
	round.keycard1, round.keycard2, round.released, round.uploaded = false, false, false, false
	round.transmitter, round.blackout, round.blackoutDone, round.dish = false, false, false, false
	round.broadcasting, round.signalCut, round.finalVent = false, false, false
	round.unlocked = {}
	round.respawnCF = nil
	round.cutsceneUntil = 0
	round.difficulty = nil
	setPhase(0)
	for k, v in { Evidence = 0, Tapes = 0, CellsFreed = 0, Keycard1 = false, Keycard2 = false, Alarm = false, Blackout = false, Broadcast = 0,
		BroadcastStalled = false, SignalCut = false, Difficulty = "", DifficultyChoosing = false, AdminFreeze = nil } do
		ReplicatedStorage:SetAttribute(k, v)
	end
	ReplicatedStorage:SetAttribute("EvidenceNeeded", Config.EvidenceNeeded)
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
	-- guards: spread over the floors (one always on the roof... later)
	local spawns = marks("GuardSpawn")
	for i = 1, d.Guards do
		local sp = spawns[(i - 1) % #spawns + 1]
		local g = spawnMonster("Guard", CFrame.new(sp.Position), floorOf(sp.Position.Y))
		g.idleUntil = os.clock() + 4 + i
	end
	setPhase(1)
	round.respawnCF = CFrame.new(0, 1, 62)
	round.startTime = os.clock()
	spawnCash()
	setObjective(("Collect EVIDENCE (0/%d) on all 3 floors. Pick locks, crack safes - and don't let the FBI guards see you."):format(Config.EvidenceNeeded))
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
	round.spawnItems()
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
		up = { flash = 2, flashSkin = "ice", sprinter = true, silent = true, sixth = true, extraLife = 1, stunPlus = 1, skin = "agent" }
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
	local skinFrom = ({ agent = "Guard", director = "Marsh", guest = "B01" })[player:GetAttribute("Up_Skin") or ""]
	local srcModel = skinFrom and ServerStorage.Monsters:FindFirstChild(skinFrom)
	if srcModel and player.Character then
		for _, cls in { "Shirt", "Pants" } do
			local from = srcModel:FindFirstChildOfClass(cls)
			if from then
				local old = player.Character:FindFirstChildOfClass(cls)
				if old then
					old:Destroy()
				end
				from:Clone().Parent = player.Character
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
	elseif cmd == "evidence" then
		while round.evidence < Config.EvidenceNeeded do
			addEvidence(player, "(admin)")
		end
		round.keycard1 = true
		ReplicatedStorage:SetAttribute("Keycard1", true)
		say("Evidence complete + guard keycard.")
	elseif cmd == "keycards" then
		round.keycard1, round.keycard2 = true, true
		ReplicatedStorage:SetAttribute("Keycard1", true)
		ReplicatedStorage:SetAttribute("Keycard2", true)
		say("Both keycards.")
	elseif cmd == "skip" then
		if round.phase <= 2 then
			while round.evidence < Config.EvidenceNeeded do
				addEvidence(player, "(admin)")
			end
			round.keycard1 = true
			round.cellsFreed = 3
			releaseB01()
		elseif round.phase == 3 then
			round.keycard2 = true
			round.uploaded = true
			setPhase(4)
			round.respawnCF = CFrame.new(28, 43, 0)
			setObjective("Boot the TRANSMITTER in UPLINK CONTROL (floor 3, north-east).")
		elseif round.phase == 4 then
			round.blackout, round.blackoutDone, round.transmitter = false, true, true
			ReplicatedStorage:SetAttribute("Blackout", false)
			setPhase(5)
			round.respawnCF = CFrame.new(20, 64, -50)
			setObjective("Get to the ROOF. ALIGN THE DISH, then START THE BROADCAST.")
		elseif round.phase == 5 then
			round.dish = true
			round.cutSignal()
		end
		say("Skipped to phase " .. round.phase .. ".")
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
	dbg.Name = "HQDebug"
	dbg.Parent = ServerStorage
	dbg.OnInvoke = function(cmd, arg)
		if cmd == "state" then
			local list = {}
			for _, m in monsters do
				table.insert(list, ("%s %s %s"):format(m.kind, m.state, tostring(m.feetPos)))
			end
			return ("phase=%d evidence=%d cells=%d k1=%s k2=%s uploaded=%s tx=%s blackout=%s dish=%s cut=%s | %s"):format(round.phase, round.evidence, round.cellsFreed,
				tostring(round.keycard1), tostring(round.keycard2), tostring(round.uploaded), tostring(round.transmitter), tostring(round.blackout), tostring(round.dish), tostring(round.signalCut), table.concat(list, "; "))
		elseif cmd == "code" then
			return round.safeCode
		elseif cmd == "admin" then
			AdminRemote:FireAllClients() -- no-op
		end
	end
end
round.resetRound()
