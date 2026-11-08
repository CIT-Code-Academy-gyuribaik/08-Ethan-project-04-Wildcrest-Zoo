-- Closing Time (zoo place): round flow, objectives, hiding, items, monsters.
--
-- Players arrive from the lobby place by teleport. Flow: the office is locked
-- -> get the keycard from the Research Lab under the Reptile House
-- (containment breach: the Stalker gets out) -> open the office and crack the
-- safe -> take the money (alarm: the Behemoth breaks out, more Crawlers) ->
-- carry it out the front gate. Then everyone goes back to the lobby.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("ZooConfig"))
local PlaceIds = require(ReplicatedStorage:WaitForChild("PlaceIds"))
local zoo = workspace:WaitForChild("Zoo")
local start = zoo:WaitForChild("Start")
local exitZone = zoo:WaitForChild("FrontGate"):WaitForChild("ExitZone")
local buildings = zoo:WaitForChild("Buildings")
local reptile = buildings:WaitForChild("ReptileHouse")
local office = buildings:WaitForChild("Office")
local yard = buildings:WaitForChild("MaintenanceYard")
local lab = zoo:WaitForChild("ResearchLab")

local monstersFolder = zoo:FindFirstChild("Monsters") or Instance.new("Folder")
monstersFolder.Name = "Monsters"
monstersFolder.Parent = zoo
local itemsFolder = zoo:FindFirstChild("Items") or Instance.new("Folder")
itemsFolder.Name = "Items"
itemsFolder.Parent = zoo

-- Remotes ---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "ZooRemotes"
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
local AddBattery = remote("AddBattery")
local Escaped = remote("Escaped")
local StateRemote = remote("State")
local LeaveHide = remote("LeaveHide")
local StunRemote = remote("Stun") -- client -> server (look direction)
local RadarPing = remote("RadarPing") -- (duration)
local ChooseDifficulty = remote("ChooseDifficulty") -- client -> server (name)
local OpenShop = remote("OpenShop") -- server -> client
local ShopFunction = Instance.new("RemoteFunction")
ShopFunction.Name = "Shop"
ShopFunction.Parent = remotes

-- Round state -------------------------------------------------------------------
local round = { active = false, phase = 0, startTime = 0, hasKeycard = false, officeOpen = false, safeOpen = false, carrier = nil, ending = false }
local roster = {} -- [player] = { lives, sprinting, moving, flashlight, hidden }
round.id = 0 -- bumps every round so timers from an old round can't fire into a new one
local function D()
	return Config.Difficulties[round.difficulty or Config.DefaultDifficulty] or Config.Difficulties.Normal
end
local savedLives = {} -- [userId] = lives, kept if you die some other way and respawn

local function setObjective(text)
	ReplicatedStorage:SetAttribute("ZooObjective", text)
end
local function setPhase(p)
	round.phase = p
	ReplicatedStorage:SetAttribute("ZooPhase", p)
	ReplicatedStorage:SetAttribute("Alarm", p >= 3)
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
local function charParts(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head")
	if root and hum and hum.Health > 0 then
		return char, root, hum, head
	end
	return nil
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
	pr.MaxActivationDistance = distance or 8
	pr.RequiresLineOfSight = false
	pr.Parent = parent
	return pr
end

-- Doors -------------------------------------------------------------------------
local doorHome = {}
local function setDoor(door, open)
	doorHome[door] = doorHome[door] or door.CFrame
	local goal = open and doorHome[door] * CFrame.new(0, door.Size.Y - 0.4, 0) or doorHome[door]
	TweenService:Create(door, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { CFrame = goal }):Play()
	door.CanCollide = not open
	door:SetAttribute("Open", open)
end
local researchDoor = reptile:WaitForChild("ResearchDoor")
local keycardDoor = office:WaitForChild("KeycardDoor")
local readerLight = office:WaitForChild("ReaderLight")

local researchPrompt = prompt(researchDoor, "Open", "Research Door", 0.5)
researchPrompt.Triggered:Connect(function(player)
	if not roster[player] then
		return
	end
	local open = not researchDoor:GetAttribute("Open")
	setDoor(researchDoor, open)
	researchPrompt.ActionText = open and "Close" or "Open"
end)

local officePrompt = prompt(keycardDoor, "Open", "Cash Office", 0.5)
officePrompt.Triggered:Connect(function(player)
	if not roster[player] or round.officeOpen then
		return
	end
	if not round.power then
		Notify:FireClient(player, "The card reader is dead. There's no power.")
		if round.phase == 1 then
			setObjective("No power! Find " .. Config.FusesNeeded .. " fuses and put them in the generator below the Reptile House.")
		end
		return
	end
	if not round.hasKeycard then
		Notify:FireClient(player, "Locked. The card reader needs a staff keycard.")
		if round.phase == 1 then
			setObjective("The office is locked. Find a keycard - try Research, below the Reptile House.")
		end
		return
	end
	round.officeOpen = true
	readerLight.Color = Color3.fromRGB(40, 255, 80)
	setDoor(keycardDoor, true)
	officePrompt.Enabled = false
	setObjective("Crack the safe in the Cash Office.")
	notifyAll(player.DisplayName .. " unlocked the Cash Office.")
end)

-- Monsters ------------------------------------------------------------------------
local monsters = {}
local patrolPoints = { Zoo = {}, Lab = {} }
for _, p in CollectionService:GetTagged("PatrolPoint") do
	local area = p:GetAttribute("Area") or "Zoo"
	patrolPoints[area] = patrolPoints[area] or {}
	table.insert(patrolPoints[area], p.Position)
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

local function spawnMonster(kind, cframe, area)
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
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and (d:GetAttribute("Amp") or 0) > 0 then
			table.insert(joints, { motor = d, base = d.C0, amp = d:GetAttribute("Amp"), phase = d:GetAttribute("Phase") or 0 })
		end
	end
	local m = {
		kind = kind, cfg = cfg, model = model, root = model.PrimaryPart, hip = hip, area = area,
		state = "Patrol", waypoints = nil, wpIndex = 1, target = nil, lastSeenPos = nil, lastSeenTime = 0,
		idleUntil = os.clock() + 2, repathAt = 0, pathing = false, joints = joints, walkPhase = 0, yaw = 0,
		feetPos = cframe.Position,
		path = PathfindingService:CreatePath({ AgentRadius = cfg.AgentRadius, AgentHeight = cfg.AgentHeight, AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 4 }),
	}
	local snd = Config.MonsterSounds and Config.MonsterSounds[kind]
	if snd then
		local s = Instance.new("Sound")
		s.Name = "Growl"
		s.SoundId = snd.Id
		s.Volume = snd.Volume
		s.PlaybackSpeed = snd.Pitch
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 8
		s.RollOffMaxDistance = snd.Range
		s.Parent = m.root
		m.growl = s
		m.nextGrowl = os.clock() + math.random(3, 8)
	end
	table.insert(monsters, m)
	return m
end

local function feet(m)
	return m.feetPos
end

local function computePath(m, goal)
	if m.pathing then
		return
	end
	m.pathing = true
	task.spawn(function()
		local ok = pcall(function()
			m.path:ComputeAsync(feet(m) + Vector3.new(0, 1, 0), goal)
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
				m.badGoals = m.badGoals or {} -- remember patrol spots it can't reach
				m.badGoals[goal] = true
			end
		end
	end)
end

local function pickPatrol(m)
	local list = patrolPoints[m.area] or patrolPoints.Zoo
	if #list == 0 then
		return
	end
	local here = feet(m)
	local goal
	for _ = 1, 6 do
		goal = list[math.random(#list)]
		if (goal - here).Magnitude > 20 and not (m.badGoals and m.badGoals[goal]) then
			break
		end
	end
	computePath(m, goal)
end

local function hasLOS(fromPos, toPos)
	return workspace:Raycast(fromPos, toPos - fromPos, rayParams()) == nil
end
local function eyePos(m)
	return m.root.Position + Vector3.new(0, m.hip * 0.6, 0)
end

-- SAFE ZONE by the gate: monsters can't enter it, sense you in it, or catch you in it.
local safeArea = zoo:FindFirstChild("SafeZone") and zoo.SafeZone:FindFirstChild("Area")
local function inSafeZone(pos)
	if not safeArea then
		return false
	end
	local rel = safeArea.CFrame:PointToObjectSpace(pos)
	local h = safeArea.Size / 2
	return math.abs(rel.X) <= h.X and math.abs(rel.Z) <= h.Z and math.abs(rel.Y) <= h.Y + 4
end

-- "see", "hear" or nil
local function perceive(m, player, st)
	if player:GetAttribute("AdminGod") then
		return nil
	end
	if st.hidden or os.clock() < (st.protectedUntil or 0) then
		return nil
	end
	do
		local _, r = charParts(player)
		if r and inSafeZone(r.Position) then
			return nil
		end
	end
	local _, root, _, head = charParts(player)
	if not root then
		return nil
	end
	local cfg = m.cfg
	local target = (head or root).Position
	local eye = eyePos(m)
	local dist = (target - eye).Magnitude
	if dist <= cfg.Sense + m.hip * 0.5 and hasLOS(eye, target) then
		return "see"
	end
	local range = st.flashlight and cfg.SightFlashlight or cfg.Sight
	if range > 0 and dist <= range then
		local angle = math.deg(math.acos(math.clamp(m.root.CFrame.LookVector:Dot((target - eye).Unit), -1, 1)))
		if angle <= cfg.FOV / 2 and hasLOS(eye, target) then
			return "see"
		end
	end
	local hear = st.sprinting and cfg.Hearing or (st.moving and cfg.Hearing * (cfg.WalkHearing or 0.25) or 0)
	if dist <= hear then
		return "hear"
	end
	return nil
end

local catchPlayer


local function think(m)
	if ReplicatedStorage:GetAttribute("AdminFreeze") then
		return
	end
	if os.clock() < (m.stunnedUntil or 0) then
		m.lastMoveAt = os.clock()
		return
	end
	-- watchdog: a monster that should be moving but hasn't for a while gets a fresh start
	m.lastMoveAt = m.lastMoveAt or os.clock()
	if os.clock() - m.lastMoveAt > 12 and os.clock() > (m.idleUntil or 0) then
		m.lastMoveAt = os.clock()
		m.pathing = false
		m.waypoints = nil
		m.badGoals = nil
		m.failedAt = nil
		m.target = nil
		m.huntHidden = nil
		m.state = "Patrol"
		m.model:SetAttribute("Chasing", nil)
	end
	local bestSeen, bestDist, heardPos = nil, math.huge, nil
	for _, player in inGamePlayers() do
		local sense = perceive(m, player, roster[player])
		local _, root = charParts(player)
		if sense and root then
			local d = (root.Position - m.root.Position).Magnitude
			if sense == "see" and d < bestDist then
				bestSeen, bestDist = player, d
			elseif sense == "hear" then
				heardPos = root.Position
			end
		end
	end

	-- STALKER SCENT: hiding doesn't work. Get within range of a hidden player and it knows.
	local ab0 = Config.Abilities and Config.Abilities[m.kind]
	if m.kind == "Stalker" and ab0 and ab0.ScentRange and m.state ~= "Hunt" then
		for _, player in inGamePlayers() do
			local st = roster[player]
			local inside = st.hidden and st.hidden:FindFirstChild("Inside")
			if inside and not player:GetAttribute("AdminGod") and os.clock() >= (st.protectedUntil or 0) and (inside.Position - m.root.Position).Magnitude < ab0.ScentRange then
				m.huntHidden = st.hidden
				m.target = player
				m.state = "Hunt"
				m.model:SetAttribute("Chasing", player.Name)
				if m.growl then
					m.growl:Play()
				end
				Notify:FireClient(player, "It's sniffing at the door... it can SMELL you!", Color3.fromRGB(255, 80, 80))
				break
			end
		end
	end
	if m.growl and os.clock() > m.nextGrowl and (m.kind ~= "Stalker" or m.state == "Chase") then
		m.growl.PlaybackSpeed = (Config.MonsterSounds[m.kind].Pitch or 1) * (0.9 + math.random() * 0.2)
		m.growl:Play()
		m.nextGrowl = os.clock() + (m.state == "Chase" and math.random(2, 4) or math.random(6, 12))
	end
	if bestSeen then
		if m.state ~= "Chase" and m.growl then
			m.growl:Play() -- it spotted you
			m.nextGrowl = os.clock() + 3
		end
		local _, root = charParts(bestSeen)
		m.model:SetAttribute("Chasing", bestSeen.Name)
		m.state = "Chase"
		m.target = bestSeen
		m.lastSeenPos = root.Position
		m.lastSeenTime = os.clock()
		m.huntHidden = nil
	elseif m.state == "Chase" then
		local st = m.target and roster[m.target]
		if st and st.hidden and not st.huntChecked then
			-- You hid. It only finds you if it was right behind you, and even
			-- then it's a coin flip. Otherwise it loses you and searches around.
			st.huntChecked = true
			local inside = st.hidden:FindFirstChild("Inside")
			local close = inside and (inside.Position - m.root.Position).Magnitude < 10 + m.hip * 0.5
			if m.kind == "Stalker" or (close and os.clock() - m.lastSeenTime < 1.2 and math.random() < 0.5) then
				m.huntHidden = st.hidden
				m.state = "Hunt"
			else
				m.state = "Search"
				m.searchUntil = os.clock() + 6
				m.target = nil
				m.model:SetAttribute("Chasing", nil)
				computePath(m, m.lastSeenPos)
			end
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
			m.model:SetAttribute("Chasing", nil)
			return
		end
		local here = feet(m)
		local ab = Config.Abilities and Config.Abilities[m.kind]
		local flatTo = Vector3.new(root.Position.X - here.X, 0, root.Position.Z - here.Z)
		if ab and m.kind == "Crawler" and flatTo.Magnitude < ab.PounceRange and os.clock() > (m.nextPounce or 0) then
			-- POUNCE: a sudden lunge
			m.pounceUntil = os.clock() + ab.PounceTime
			m.nextPounce = os.clock() + ab.PounceCooldown
			if m.growl then
				m.growl:Play()
			end
		elseif ab and m.kind == "Behemoth" and not m.charging and os.clock() > (m.nextCharge or 0)
			and flatTo.Magnitude > ab.ChargeMinRange and flatTo.Magnitude < ab.ChargeMaxRange and hasLOS(eyePos(m), root.Position) then
			-- CHARGE: straight line, can't turn
			m.charging = true
			m.chargeUntil = os.clock() + ab.ChargeTime
			m.chargeDir = flatTo.Unit
			m.nextCharge = os.clock() + ab.ChargeCooldown
			m.model:SetAttribute("Charging", true)
			if m.growl then
				m.growl:Play()
			end
		end
		local dy = math.abs(root.Position.Y - 3 - here.Y)
		if (root.Position - here).Magnitude < 30 and dy < 4 and hasLOS(eyePos(m), root.Position) then
			m.waypoints = { Vector3.new(root.Position.X, here.Y, root.Position.Z) }
			m.wpIndex = 1
		elseif os.clock() > m.repathAt then
			m.repathAt = os.clock() + 0.5
			computePath(m, root.Position)
		end
	elseif m.state == "Hunt" then
		local spot = m.huntHidden
		if not spot or not spot:GetAttribute("Occupant") then
			m.state = "Search"
			m.searchUntil = os.clock() + 6
			return
		end
		local inside = spot:FindFirstChild("Inside")
		local front = inside.Position + inside.CFrame.LookVector * 3
		local flat = Vector3.new(front.X - m.feetPos.X, 0, front.Z - m.feetPos.Z)
		if flat.Magnitude < m.cfg.CatchRange + 1.5 then
			local victim = Players:FindFirstChild(spot:GetAttribute("Occupant"))
			if victim then
				catchPlayer(m, victim)
			end
			m.state = "Patrol"
		elseif os.clock() > m.repathAt then
			m.repathAt = os.clock() + 0.6
			computePath(m, front)
		end
	elseif m.state == "Search" then
		if os.clock() > (m.searchUntil or 0) then
			m.state = "Patrol"
			m.waypoints = nil
		elseif not m.waypoints and not m.pathing then
			computePath(m, (m.lastSeenPos or feet(m)) + Vector3.new(math.random(-14, 14), 0, math.random(-14, 14)))
		end
	elseif m.state == "Patrol" then
		if not m.waypoints and not m.pathing and os.clock() > m.idleUntil and os.clock() > (m.failedAt or 0) + 2 then
			pickPatrol(m)
		end
	end
end

local function step(m, dt)
	if ReplicatedStorage:GetAttribute("AdminFreeze") then
		return
	end
	if os.clock() < (m.stunnedUntil or 0) then
		if m.model:GetAttribute("Stunned") then
			m.root.CFrame = CFrame.new(m.feetPos + Vector3.new(0, m.hip * 0.85, 0)) * CFrame.Angles(0, m.yaw, 0)
				* CFrame.Angles((math.random() - 0.5) * 0.12, 0, (math.random() - 0.5) * 0.12)
		end
		return
	end
	local speed = (m.state == "Chase" or m.state == "Hunt") and m.cfg.ChaseSpeed or m.cfg.PatrolSpeed
	if round.phase >= 3 then
		speed *= 1.1
	end
	local ab = Config.Abilities and Config.Abilities[m.kind]
	if ab and m.pounceUntil and os.clock() < m.pounceUntil then
		speed = ab.PounceSpeed
	end
	local moving = false
	if m.charging then
		-- charging: straight ahead, no steering; a wall (or running out of steam) leaves it dazed
		local here = feet(m)
		local hit = workspace:Raycast(here + Vector3.new(0, m.hip, 0), m.chargeDir * (m.cfg.AgentRadius + 3), rayParams())
		if hit or os.clock() > m.chargeUntil then
			m.charging = false
			m.model:SetAttribute("Charging", nil)
			m.stunnedUntil = os.clock() + (hit and ab.DazeTime or ab.DazeTime * 0.5)
			m.waypoints = nil
			if hit and m.growl then
				m.growl:Play()
			end
		else
			local nextFeet = here + m.chargeDir * ab.ChargeSpeed * dt
			if inSafeZone(nextFeet) then
				m.chargeUntil = 0
				nextFeet = here
			end
			m.feetPos = nextFeet
			m.yaw = math.atan2(-m.chargeDir.X, -m.chargeDir.Z)
			moving = true
			speed = ab.ChargeSpeed
		end
	elseif m.waypoints then
		local wp = m.waypoints[m.wpIndex]
		if wp then
			local here = feet(m)
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
				local newFeet = here + dir * math.min(d, speed * dt)
				local ny = here.Y + math.clamp(wp.Y - here.Y, -speed * dt, speed * dt)
				local nf = Vector3.new(newFeet.X, ny, newFeet.Z)
				if inSafeZone(nf) and not inSafeZone(here) then
					-- turned back at the edge of the safe zone
					m.waypoints = nil
					if m.state == "Chase" or m.state == "Hunt" then
						m.state = "Search"
						m.searchUntil = os.clock() + 4
						m.target = nil
						m.model:SetAttribute("Chasing", nil)
					end
					nf = here
				end
				m.feetPos = nf
				local targetYaw = math.atan2(-dir.X, -dir.Z)
				local diff = (targetYaw - m.yaw + math.pi) % (2 * math.pi) - math.pi
				m.yaw += diff * math.min(1, dt * 8)
				moving = true
			end
		else
			m.waypoints = nil
		end
	end
	-- body bob/sway + limb swing
	if moving then
		m.lastMoveAt = os.clock()
	end
	m.walkPhase += dt * (moving and speed * 0.55 or 1.2)
	local bob = m.model:GetAttribute("Bob") or 0
	local sway = m.model:GetAttribute("Sway") or 0
	local k = moving and 1 or 0.25
	m.root.CFrame = CFrame.new(m.feetPos + Vector3.new(0, m.hip + math.abs(math.sin(m.walkPhase)) * bob * k, 0))
		* CFrame.Angles(0, m.yaw, 0) * CFrame.Angles(0, 0, math.sin(m.walkPhase) * sway * k)
	for _, j in m.joints do
		local a = moving and j.amp or j.amp * 0.12
		j.motor.C0 = j.base * CFrame.Angles(math.sin(m.walkPhase + j.phase) * a, 0, 0)
	end
	if m.state == "Chase" and m.target then
		local _, root = charParts(m.target)
		local st = roster[m.target]
		if root and st and not st.hidden and (root.Position - m.root.Position).Magnitude <= m.cfg.CatchRange + m.hip * 0.5 then
			catchPlayer(m, m.target)
		end
	end
end

local thinkAcc = 0
RunService.Heartbeat:Connect(function(dt)
	if not round.active then
		return
	end
	thinkAcc += dt
	local doThink = thinkAcc >= 0.2
	if doThink then
		thinkAcc = 0
	end
	for i = #monsters, 1, -1 do
		local m = monsters[i]
		if not m.model.Parent then
			table.remove(monsters, i)
		else
			if doThink then
				think(m)
			end
			step(m, dt)
		end
	end
end)

local function clearMonsters()
	for _, m in monsters do
		m.model:Destroy()
	end
	table.clear(monsters)
end

-- Money ---------------------------------------------------------------------------
local moneyBag
local function makeBag()
	local bag = Instance.new("Part")
	bag.Name = "MoneyBag"
	bag.Size = Vector3.new(2, 2.2, 1.6)
	bag.Color = Color3.fromRGB(70, 120, 60)
	bag.Material = Enum.Material.Fabric
	bag.CanCollide = false
	bag.Massless = true
	local tie = Instance.new("Part")
	tie.Name = "Tie"
	tie.Size = Vector3.new(0.8, 0.5, 0.8)
	tie.Color = Color3.fromRGB(200, 170, 80)
	tie.Material = Enum.Material.Fabric
	tie.CanCollide = false
	tie.Massless = true
	tie.CFrame = bag.CFrame * CFrame.new(0, 1.3, 0)
	local w = Instance.new("WeldConstraint")
	w.Part0 = bag
	w.Part1 = tie
	w.Parent = tie
	tie.Parent = bag
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 30)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 40
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(120, 255, 120)
	t.TextStrokeTransparency = 0.3
	t.Text = "$$$"
	t.Parent = gui
	gui.Parent = bag
	bag.Parent = itemsFolder
	return bag
end

local pickUpBag
local function dropBag(position)
	if not moneyBag then
		return
	end
	local weld = moneyBag:FindFirstChild("CarryWeld")
	if weld then
		weld:Destroy()
	end
	if round.carrier then
		round.carrier:SetAttribute("CarryingMoney", false)
	end
	round.carrier = nil
	ReplicatedStorage:SetAttribute("MoneyCarrier", "")
	moneyBag.Anchored = true
	moneyBag.CFrame = CFrame.new(position)
	prompt(moneyBag, "Take", "Money Bag", 0.3).Triggered:Connect(function(p)
		pickUpBag(p)
	end)
end

local function startAlarm()
	setPhase(3)
	setObjective((round.sampleCount or 0) >= Config.SamplesTotal and "ALARM! Escape through the front gate with the money!"
		or "ALARM! Get the last samples (stun the monsters!) and escape through the front gate.")
	notifyAll("ALARM! Something huge just woke up...", Color3.fromRGB(255, 70, 60))
	local blast = yard:FindFirstChild("BlastDoor")
	if blast then
		blast.Anchored = false
		blast.CanCollide = false
		blast.AssemblyLinearVelocity = Vector3.new(0, 30, 60)
		Debris:AddItem(blast, 3)
	end
	local spawnAt = CollectionService:GetTagged("BehemothSpawn")[1]
	local id = round.id
	task.delay(1.5, function()
		if round.active and round.id == id and spawnAt then
			spawnMonster("Behemoth", CFrame.new(spawnAt.Position), "Zoo").idleUntil = 0
		end
	end)
	local spawns = CollectionService:GetTagged("CrawlerSpawn")
	for i = 1, D().AlarmCrawlers or Config.ExtraCrawlersOnAlarm do
		local sp = spawns[(i % #spawns) + 1]
		if sp then
			spawnMonster("Crawler", CFrame.new(sp.Position), "Zoo")
		end
	end
	for _, m in monsters do
		if m.kind == "Stalker" then
			m.area = "Zoo"
			m.waypoints = nil
		end
	end
end

function pickUpBag(player)
	local char, root = charParts(player)
	if not char or not roster[player] or roster[player].hidden or round.carrier or not moneyBag then
		return
	end
	local pr = moneyBag:FindFirstChildOfClass("ProximityPrompt")
	if pr then
		pr:Destroy()
	end
	moneyBag.Anchored = false
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or root
	moneyBag.CFrame = torso.CFrame * CFrame.new(0, 0, 1.4)
	local w = Instance.new("WeldConstraint")
	w.Name = "CarryWeld"
	w.Part0 = torso
	w.Part1 = moneyBag
	w.Parent = moneyBag
	round.carrier = player
	player:SetAttribute("CarryingMoney", true)
	ReplicatedStorage:SetAttribute("MoneyCarrier", player.DisplayName)
	if round.phase < 3 then
		startAlarm()
	else
		notifyAll(player.DisplayName .. " has the money!")
	end
end

local safe = office:WaitForChild("Safe")
local safeDoor = safe:WaitForChild("SafeDoor")
local safeHome = safeDoor.CFrame
local function setupSafe()
	safeDoor.CFrame = safeHome
	local pr = prompt(safeDoor, "Crack Safe", "Office Safe", Config.SafeCrackTime)
	pr.Triggered:Connect(function(player)
		if not roster[player] or round.safeOpen or not round.officeOpen then
			if not round.officeOpen then
				Notify:FireClient(player, "You need to get into the office first.")
			end
			return
		end
		round.safeOpen = true
		pr.Enabled = false
		safeDoor.CFrame = safeHome * CFrame.new(-2, 0, -2) * CFrame.Angles(0, math.rad(80), 0)
		moneyBag = makeBag()
		dropBag(safeHome.Position + Vector3.new(0, -1.5, 3))
		setObjective("Take the money.")
	end)
end

-- Keycard -----------------------------------------------------------------------
local labColors = {}
for _, d in lab:GetDescendants() do
	if d:IsA("PointLight") or (d:IsA("BasePart") and d.Name == "Light") then
		labColors[d] = d.Color
	end
end
local cellGlass = lab:FindFirstChild("CellGlass", true)

local function spawnKeycard()
	local spot = CollectionService:GetTagged("KeycardSpot")[1]
	if not spot then
		return
	end
	local keycard = Instance.new("Part")
	keycard.Name = "Keycard"
	keycard.Size = Vector3.new(0.9, 0.08, 1.4)
	keycard.Color = Color3.fromRGB(40, 140, 255)
	keycard.Material = Enum.Material.Neon
	keycard.Anchored = true
	keycard.CanCollide = false
	keycard.CFrame = CFrame.new(spot.Position) * CFrame.Angles(0, 0.4, 0)
	keycard.Parent = itemsFolder
	local light = Instance.new("PointLight")
	light.Color = keycard.Color
	light.Range = 6
	light.Parent = keycard
	prompt(keycard, "Take", "Staff Keycard", 0.3).Triggered:Connect(function(player)
		if not roster[player] or round.hasKeycard then
			return
		end
		if round.choosing then
			Notify:FireClient(player, "Choose a difficulty first.")
			return
		end
		round.hasKeycard = true
		keycard:Destroy()
		setPhase(2)
		setObjective(round.power and "CONTAINMENT BREACH. Get back up and unlock the Cash Office (north of the park)."
			or "CONTAINMENT BREACH. Restore power (fuses -> generator), then unlock the Cash Office.")
		notifyAll("CONTAINMENT BREACH - SUBJECT S-01 RELEASED", Color3.fromRGB(255, 70, 60))
		if cellGlass then
			for _ = 1, 14 do
				local shard = Instance.new("Part")
				shard.Size = Vector3.new(math.random() + 0.3, math.random() + 0.3, 0.1)
				shard.Color = cellGlass.Color
				shard.Material = Enum.Material.Glass
				shard.Transparency = 0.4
				shard.CanCollide = false
				shard.CFrame = cellGlass.CFrame * CFrame.new(math.random(-10, 10), math.random(-5, 5), 0)
				shard.AssemblyLinearVelocity = Vector3.new(math.random(-10, 10), math.random(0, 10), math.random(5, 20))
				shard.Parent = itemsFolder
				Debris:AddItem(shard, 4)
			end
			cellGlass.Transparency = 1
			cellGlass.CanCollide = false
		end
		for d in labColors do
			d.Color = Color3.fromRGB(255, 40, 30)
		end
		local sp = CollectionService:GetTagged("StalkerSpawn")[1]
		local id = round.id
		task.delay(1, function()
			if round.active and round.id == id and sp then
				spawnMonster("Stalker", CFrame.new(sp.Position), "Lab").idleUntil = 0
			end
		end)
	end)
end

-- Batteries ---------------------------------------------------------------------------
local function spawnBattery(spot)
	local b = Instance.new("Part")
	b.Name = "Battery"
	b.Size = Vector3.new(0.6, 1.2, 0.6)
	b.Color = Color3.fromRGB(240, 200, 40)
	b.Material = Enum.Material.Neon
	b.Anchored = true
	b.CanCollide = false
	b.CFrame = CFrame.new(spot.Position)
	b.Parent = itemsFolder
	prompt(b, "Take", "Battery", 0).Triggered:Connect(function(player)
		if not roster[player] or not b.Parent then
			return
		end
		b:Destroy()
		AddBattery:FireClient(player, Config.BatteryPickup)
		local id = round.id
		task.delay(Config.BatteryRespawn, function()
			if round.active and round.id == id then
				spawnBattery(spot)
			end
		end)
	end)
end

for _, n in CollectionService:GetTagged("Note") do
	prompt(n, "Read", "Note", 0, 7).Triggered:Connect(function(player)
		ShowNote:FireClient(player, n:GetAttribute("NoteText") or "")
	end)
end

-- Hiding ----------------------------------------------------------------------------------
local function unhide(player, push)
	local st = roster[player]
	local spot = st and st.hidden
	if not spot then
		return
	end
	st.hidden = nil
	spot:SetAttribute("Occupant", nil)
	player:SetAttribute("Hidden", false)
	local _, root = charParts(player)
	if root then
		root.Anchored = false
		if push ~= false then
			local inside = spot:FindFirstChild("Inside")
			local out = inside.Position + inside.CFrame.LookVector * 3.6
			root.CFrame = CFrame.lookAt(out, out + inside.CFrame.LookVector)
		end
	end
	local pr = spot:FindFirstChild("Door") and spot.Door:FindFirstChildOfClass("ProximityPrompt")
	if pr then
		pr.Enabled = true
	end
end

for _, spot in CollectionService:GetTagged("HideSpot") do
	local door = spot:FindFirstChild("Door")
	local inside = spot:FindFirstChild("Inside")
	if door and inside then
		local pr = prompt(door, "Hide", (spot.Name:gsub("(%l)(%u)", "%1 %2")), 0, 7)
		pr.Triggered:Connect(function(player)
			local st = roster[player]
			local _, root = charParts(player)
			if not st or not root or st.hidden or spot:GetAttribute("Occupant") then
				return
			end
			st.hidden = spot
			st.huntChecked = false
			spot:SetAttribute("Occupant", player.Name)
			player:SetAttribute("Hidden", true)
			pr.Enabled = false
			root.Anchored = true
			root.CFrame = inside.CFrame
		end)
	end
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

-- Infinite Lives game pass -------------------------------------------------------
local passCache = {}
local function ownsInfiniteLives(player)
	if not Config.InfiniteLivesPassId or Config.InfiniteLivesPassId == 0 then
		return false
	end
	if passCache[player.UserId] == nil then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.InfiniteLivesPassId)
		end)
		passCache[player.UserId] = ok and owns or false
	end
	return passCache[player.UserId]
end
local nokiaCache = {}
local function ownsNokia(player)
	local id = Config.NokiaFlashlightPassId
	if not id or id == 0 then
		return false
	end
	if nokiaCache[player.UserId] == nil then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		nokiaCache[player.UserId] = ok and owns or false
	end
	return nokiaCache[player.UserId]
end
local function applyInfinite(player)
	player:SetAttribute("NokiaFlashlight", ownsNokia(player))
	local st = roster[player]
	if st and ownsInfiniteLives(player) then
		st.infinite = true
	end
	player:SetAttribute("InfiniteLives", ownsInfiniteLives(player))
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == Config.NokiaFlashlightPassId then
		nokiaCache[player.UserId] = true
		player:SetAttribute("NokiaFlashlight", true)
		Notify:FireClient(player, "Nokia Flashlight unlocked! It will never die.", Color3.fromRGB(120, 255, 140))
	end
	if purchased and passId == Config.InfiniteLivesPassId then
		passCache[player.UserId] = true
		applyInfinite(player)
		Notify:FireClient(player, "Infinite Lives unlocked! Thanks for the support.", Color3.fromRGB(120, 255, 140))
	end
end)

-- Leaving, catching, winning ------------------------------------------------------------
local resetRound

local function removeFromRound(player, keepLives)
	if not roster[player] then
		return
	end
	if keepLives then
		savedLives[player.UserId] = roster[player].lives
	else
		savedLives[player.UserId] = nil
	end
	unhide(player, false)
	if round.carrier == player then
		local _, root = charParts(player)
		dropBag(root and root.Position or start.Position)
	end
	roster[player] = nil
	player:SetAttribute("InGame", false)
	player:SetAttribute("Lives", nil)
	for _, m in monsters do
		if m.target == player then
			m.target = nil
			m.state = "Patrol"
			m.model:SetAttribute("Chasing", nil)
		end
	end
	-- (a death isn't leaving: you respawn into the same round)
	if not keepLives and round.active and #inGamePlayers() == 0 and not round.ending then
		resetRound()
	end
end

-- Back to the lobby place. In a Studio test there is nowhere to teleport, so
-- the player just respawns into a fresh round.
local function sendToLobby(list, completedChapter)
	for _, p in list do
		removeFromRound(p)
	end
	if not RunService:IsStudio() and PlaceIds.Lobby ~= 0 then
		local ok, err = pcall(function()
			local options = Instance.new("TeleportOptions")
			if completedChapter then
				options:SetTeleportData({ Completed = completedChapter })
			end
			TeleportService:TeleportAsync(PlaceIds.Lobby, list, options)
		end)
		if ok then
			return
		end
		warn("Teleport to lobby failed: " .. tostring(err))
		for _, p in list do
			p:Kick("Couldn't get back to the lobby. Please rejoin Closing Time.")
		end
		return
	end
	for _, p in list do
		if p.Parent then
			p:LoadCharacter()
		end
	end
end

function catchPlayer(m, player)
	if player:GetAttribute("AdminGod") then
		return
	end
	local st = roster[player]
	if not st or st.beingCaught or os.clock() < (st.protectedUntil or 0) then
		return
	end
	do
		local _, r = charParts(player)
		if r and inSafeZone(r.Position) then
			return
		end
	end
	st.beingCaught = true
	local _, root = charParts(player)
	if st.hidden then
		unhide(player, true)
	end
	if round.carrier == player and root then
		dropBag(root.Position - Vector3.new(0, 2, 0))
	end
	if not st.infinite then
		st.lives -= 1
		player:SetAttribute("Lives", st.lives)
	end
	Caught:FireClient(player, m.kind, st.infinite and -1 or st.lives)
	if root then
		root.Anchored = true
	end
	m.stunnedUntil = os.clock() + 3
	m.state = "Patrol"
	m.target = nil
	m.waypoints = nil
	m.model:SetAttribute("Chasing", nil)
	task.delay(2.2, function()
		st.beingCaught = false
		if not player.Parent or not roster[player] then
			return
		end
		local _, r2 = charParts(player)
		if st.lives <= 0 then
			notifyAll(player.DisplayName .. " was taken.", Color3.fromRGB(255, 80, 80))
			sendToLobby({ player })
			return
		end
		if r2 then
			r2.Anchored = false
			r2.CFrame = start.CFrame + Vector3.new(math.random(-3, 3), 3, 0)
		end
		st.protectedUntil = os.clock() + D().Protect
		player:SetAttribute("Protected", true)
		task.delay(D().Protect, function()
			if player.Parent then
				player:SetAttribute("Protected", nil)
			end
		end)
		-- no spawn camping: anything near the gate retreats to the far side of the park
		for _, mon in monsters do
			if mon.model.Parent and (mon.feetPos - start.Position).Magnitude < 70 then
				local list = patrolPoints[mon.area] or patrolPoints.Zoo
				local far, farD = nil, 0
				for _, pt in list do
					local d = (pt - start.Position).Magnitude
					if d > farD then
						far, farD = pt, d
					end
				end
				if far then
					mon.feetPos = far
					mon.waypoints = nil
					mon.state = "Patrol"
					mon.target = nil
					mon.charging = false
					mon.model:SetAttribute("Charging", nil)
					mon.model:SetAttribute("Chasing", nil)
					mon.idleUntil = os.clock() + 4
				end
			end
		end
		Notify:FireClient(player, st.infinite and "You got away... barely. (Infinite Lives)" or ("You got away... barely. Lives left: " .. st.lives))
	end)
end

local function win()
	if round.ending then
		return
	end
	round.ending = true
	local secs = math.floor(os.clock() - round.startTime)
	-- Nothing can catch you during the escape cutscene.
	clearMonsters()
	for _, p in inGamePlayers() do
		local _, root = charParts(p)
		if root then
			root.Anchored = true
		end
	end
	local reward = (Config.EscapeReward[round.difficulty or "Normal"] or 250) + (round.sampleCount or 0) * (Config.SampleReward or 0)
	for _, p in inGamePlayers() do
		round.addCash(p, reward)
		Escaped:FireClient(p, secs, round.sampleCount or 0, Config.SamplesTotal, round.difficulty, reward)
	end
	setObjective("You escaped with the money!")
	task.delay(Config.ReturnToLobbyDelay, function()
		local list = inGamePlayers()
		resetRound()
		sendToLobby(list, 1) -- tells the lobby: Chapter 1 beaten (unlocks Chapter 2)
	end)
end

task.spawn(function()
	while true do
		task.wait(0.2)
		if round.active and not round.ending then
			for _, p in inGamePlayers() do
				local _, root = charParts(p)
				if root then
					local rel = exitZone.CFrame:PointToObjectSpace(root.Position)
					local h = exitZone.Size / 2
					if math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y + 3 and math.abs(rel.Z) <= h.Z then
						if round.carrier == p and (round.sampleCount or 0) < Config.SamplesTotal then
							Notify:FireClient(p, ("You can't leave yet - you still need samples (%d/%d)."):format(round.sampleCount or 0, Config.SamplesTotal))
							root.CFrame = start.CFrame + Vector3.new(0, 3, 0)
						elseif round.carrier == p then
							win()
						else
							Notify:FireClient(p, "You can't leave without the money!")
							root.CFrame = start.CFrame + Vector3.new(0, 3, 0)
						end
					end
				end
			end
		end
	end
end)

-- Puzzles: power fuses, stun gun, samples --------------------------------------------
local labLights = {}
for _, d in lab:GetDescendants() do
	if d:IsA("PointLight") or d:IsA("SpotLight") then
		table.insert(labLights, d)
	end
end
local generator
for _, d in lab:GetDescendants() do
	if d:IsA("BasePart") and d.Name == "Generator" then
		generator = d
	end
end
local function setPower(on)
	round.power = on
	ReplicatedStorage:SetAttribute("ZooPower", on)
	for i, l in labLights do
		-- with no power only a few dim emergency lights stay on
		l.Enabled = on or i % 4 == 0
		l.Brightness = on and (l:GetAttribute("BaseBrightness") or l.Brightness) or 0.25
	end
	for _, d in lab:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Light" then
			d.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
		end
	end
	if generator then
		local hum = generator:FindFirstChild("Hum")
		if on then
			if not hum then
				hum = Instance.new("Sound")
				hum.Name = "Hum"
				hum.SoundId = Config.Sounds.Alarm
				hum.PlaybackSpeed = 0.25
				hum.Volume = 0.15
				hum.Looped = true
				hum.RollOffMaxDistance = 40
				hum.Parent = generator
			end
			hum:Play()
		elseif hum then
			hum:Stop()
		end
	end
end
for _, l in labLights do
	l:SetAttribute("BaseBrightness", l.Brightness)
end

local function setSamples()
	local n = 0
	for _ in round.samples do
		n += 1
	end
	round.sampleCount = n
	ReplicatedStorage:SetAttribute("ZooSamples", n)
	if round.phase >= 3 and n >= Config.SamplesTotal then
		setObjective("All samples secured! Escape through the front gate with the money!")
	end
end
local function giveSample(player, id, label)
	if round.samples[id] then
		return false
	end
	round.samples[id] = true
	setSamples()
	notifyAll(("%s got a sample: %s (%d/%d)"):format(player.DisplayName, label, round.sampleCount, Config.SamplesTotal), Color3.fromRGB(140, 220, 255))
	return true
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
	p.Parent = itemsFolder
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 7
	l.Brightness = 1
	l.Parent = p
	return p
end

local function spawnPuzzleItems()
	local id = round.id
	-- fuses: 3 random spots out of the candidates
	local spots = CollectionService:GetTagged("FuseSpot")
	for i = #spots, 2, -1 do
		local j = math.random(i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	for i = 1, math.min(Config.FusesNeeded, #spots) do
		local f = itemPart("Fuse", Vector3.new(0.6, 1.4, 0.6), Color3.fromRGB(255, 150, 40), CFrame.new(spots[i].Position) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
		prompt(f, "Take", "Fuse", 0.3).Triggered:Connect(function(player)
			if not roster[player] or not f.Parent then
				return
			end
			f:Destroy()
			round.fuses += 1
			ReplicatedStorage:SetAttribute("ZooFuses", round.fuses)
			notifyAll(("%s found a fuse (%d/%d)"):format(player.DisplayName, round.fuses, Config.FusesNeeded), Color3.fromRGB(255, 190, 90))
		end)
	end
	-- the generator
	if generator then
		local pr = prompt(generator, "Insert Fuses", "Generator", 1.5, 10)
		pr.Triggered:Connect(function(player)
			if not roster[player] or round.power then
				return
			end
			if round.fuses < Config.FusesNeeded then
				Notify:FireClient(player, ("The generator needs %d fuses. You have %d."):format(Config.FusesNeeded, round.fuses))
				return
			end
			pr.Enabled = false
			setPower(true)
			notifyAll("POWER RESTORED. The card readers are back on.", Color3.fromRGB(120, 255, 140))
			if round.phase < 3 and not round.officeOpen then
				setObjective(round.hasKeycard and "Power's back. Unlock the Cash Office (north of the park) with the keycard."
					or "Power's back. Now find the office keycard in the Records room down here.")
			end
		end)
	end
	-- stun gun (each player can take one) and cartridges
	local sg = CollectionService:GetTagged("StunGunSpot")[1]
	if sg then
		local gun = itemPart("StunGun", Vector3.new(0.5, 0.8, 1.8), Color3.fromRGB(80, 170, 255), CFrame.new(sg.Position))
		prompt(gun, "Take", "Stun Gun", 0.3).Triggered:Connect(function(player)
			if not roster[player] or player:GetAttribute("HasStunner") then
				return
			end
			player:SetAttribute("HasStunner", true)
			local tier = Config.ShopTier("Stun", player:GetAttribute("StunTier") or 1)
			player:SetAttribute("StunCharges", (D().StunCharges or Config.StunCharges) + (tier and tier.Bonus or 0))
			Notify:FireClient(player, "Stun gun! Press [Q] to zap a monster in front of you.", Color3.fromRGB(140, 220, 255))
		end)
	end
	local function spawnCartridge(spot)
		local c = itemPart("StunCartridge", Vector3.new(0.5, 0.5, 0.9), Color3.fromRGB(80, 170, 255), CFrame.new(spot.Position))
		prompt(c, "Take", "Stun Cartridge", 0).Triggered:Connect(function(player)
			if not roster[player] or not c.Parent then
				return
			end
			if not player:GetAttribute("HasStunner") then
				Notify:FireClient(player, "A stun cartridge... you need the stun gun from the lab's Security room.")
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
				if round.active and round.id == id then
					spawnCartridge(spot)
				end
			end)
		end)
	end
	for _, spot in CollectionService:GetTagged("CartridgeSpot") do
		spawnCartridge(spot)
	end
	-- lab samples
	for _, spot in CollectionService:GetTagged("SampleSpot") do
		local sid = spot:GetAttribute("SampleId") or "Lab"
		local jar = itemPart("Sample", Vector3.new(0.8, 1, 0.8), Color3.fromRGB(110, 255, 150), CFrame.new(spot.Position), Enum.PartType.Cylinder)
		jar.CFrame = jar.CFrame * CFrame.Angles(0, 0, math.pi / 2)
		prompt(jar, "Take", "Specimen Sample", 0.5).Triggered:Connect(function(player)
			if roster[player] and jar.Parent and giveSample(player, sid, "specimen jar") then
				jar:Destroy()
			end
		end)
	end
end

-- Stun gun shots
local lastStun = {}
StunRemote.OnServerEvent:Connect(function(player, look)
	local st = roster[player]
	local _, root, _, head = charParts(player)
	if not st or not root or st.hidden or round.ending or typeof(look) ~= "Vector3" then
		return
	end
	if not player:GetAttribute("HasStunner") then
		return
	end
	local charges = player:GetAttribute("StunCharges") or 0
	if charges <= 0 then
		Notify:FireClient(player, "Out of stun charges. Find cartridges.")
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
		local to = m.root.Position - from
		local d = to.Magnitude
		if d <= Config.StunRange + m.hip * 0.5 and look:Dot(to.Unit) > 0.75 and d < (bestD or math.huge) then
			local params = rayParams()
			local hit = workspace:Raycast(from, to, params)
			if not hit then
				best, bestD = m, d
			end
		end
	end
	if not best then
		Notify:FireClient(player, "Missed!")
		return
	end
	local m = best
	local dur = (Config.StunTime[m.kind] or 4) * D().Stun
	m.stunnedUntil = os.clock() + dur
	m.charging = false
	m.model:SetAttribute("Charging", nil)
	m.pounceUntil = nil
	m.state = "Search"
	m.searchUntil = os.clock() + dur + 4
	m.lastSeenPos = root.Position
	m.target = nil
	m.waypoints = nil
	m.model:SetAttribute("Chasing", nil)
	m.model:SetAttribute("Stunned", true)
	local fx = Instance.new("ParticleEmitter")
	fx.Name = "StunFX"
	fx.Color = ColorSequence.new(Color3.fromRGB(120, 200, 255))
	fx.LightEmission = 1
	fx.Size = NumberSequence.new(0.6, 0)
	fx.Speed = NumberRange.new(6, 12)
	fx.SpreadAngle = Vector2.new(180, 180)
	fx.Lifetime = NumberRange.new(0.2, 0.4)
	fx.Rate = 60
	fx.Parent = m.root
	local glow = Instance.new("PointLight")
	glow.Name = "StunGlow"
	glow.Color = Color3.fromRGB(120, 200, 255)
	glow.Range = 16
	glow.Brightness = 3
	glow.Parent = m.root
	if m.growl then
		m.growl:Play()
	end
	Notify:FireClient(player, "Stunned! " .. (round.samples[m.kind] and "" or "Extract a sample, quick!"), Color3.fromRGB(140, 220, 255))
	local extract
	if not round.samples[m.kind] then
		-- the prompt sits at the player's eye level (big monsters' roots are high up inside the body)
		local at = Instance.new("Attachment")
		at.Name = "SamplePoint"
		at.Position = Vector3.new(0, -m.hip + 3, 0)
		at.Parent = m.root
		extract = prompt(at, "Extract Sample", m.kind, 1.5, 10 + m.hip * 0.5)
		extract.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
		extract.Destroying:Connect(function()
			at:Destroy()
		end)
		extract.Triggered:Connect(function(p2)
			if roster[p2] and m.model:GetAttribute("Stunned") then
				giveSample(p2, m.kind, m.kind:lower() .. " tissue")
				extract:Destroy()
			end
		end)
	end
	task.delay(dur, function()
		if m.model.Parent then
			m.model:SetAttribute("Stunned", nil)
			fx:Destroy()
			glow:Destroy()
			if extract and extract.Parent then
				extract:Destroy()
			end
		end
	end)
end)
Players.PlayerRemoving:Connect(function(p)
	lastStun[p] = nil
end)

-- Security radar by the entrance ------------------------------------------------------
local radar = zoo:FindFirstChild("RadarStation")
if radar and radar:FindFirstChild("Console") then
	local pr = prompt(radar.Console, "Activate Radar", "Security Radar", 1, 9)
	pr.Triggered:Connect(function(player)
		if not roster[player] or round.ending then
			return
		end
		if not D().RadarCooldown then
			Notify:FireClient(player, "The radar is OFFLINE on Nightmare.", Color3.fromRGB(255, 80, 80))
			return
		end
		local readyAt = ReplicatedStorage:GetAttribute("RadarReadyAt") or 0
		if workspace:GetServerTimeNow() < readyAt then
			Notify:FireClient(player, ("Radar recharging... %d s"):format(math.ceil(readyAt - workspace:GetServerTimeNow())))
			return
		end
		ReplicatedStorage:SetAttribute("RadarReadyAt", workspace:GetServerTimeNow() + D().RadarCooldown)
		ReplicatedStorage:SetAttribute("RadarActiveUntil", workspace:GetServerTimeNow() + Config.RadarDuration)
		for _, p in inGamePlayers() do
			RadarPing:FireClient(p, Config.RadarDuration)
		end
		notifyAll(player.DisplayName .. " used the radar! Monsters in RED, items in YELLOW.", Color3.fromRGB(120, 255, 140))
	end)
end

-- Cash, saved upgrades and the Supply Machine shop --------------------------------------
local DataStoreService = game:GetService("DataStoreService")
local profileStore
pcall(function()
	profileStore = DataStoreService:GetDataStore("ZooProfile_v1")
end)
local profiles = {} -- [player] = { Cash, Flashlight, Shoes, Stun }
local loadedOk = {}
local function pushAttributes(player)
	local prof = profiles[player]
	if prof then
		player:SetAttribute("Cash", prof.Cash)
		player:SetAttribute("FlashTier", prof.Flashlight)
		player:SetAttribute("ShoeTier", prof.Shoes)
		player:SetAttribute("StunTier", prof.Stun)
	end
end
local function saveProfile(player)
	local prof = profiles[player]
	if not prof or not loadedOk[player] or not profileStore then
		return
	end
	pcall(function()
		profileStore:SetAsync("p_" .. player.UserId, prof)
	end)
end
local function loadProfile(player)
	local prof = { Cash = 0, Flashlight = 1, Shoes = 1, Stun = 1 }
	local ok = true
	if profileStore then
		ok = false
		for _ = 1, 3 do
			local success, data = pcall(function()
				return profileStore:GetAsync("p_" .. player.UserId)
			end)
			if success then
				ok = true
				if type(data) == "table" then
					for k, v in data do
						if type(v) == "number" then
							prof[k] = v
						end
					end
				end
				break
			end
			task.wait(1)
		end
	end
	profiles[player] = prof
	loadedOk[player] = ok -- never overwrite a save we couldn't read
	pushAttributes(player)
end
function round.addCash(player, amount)
	local prof = profiles[player]
	if not prof then
		return
	end
	prof.Cash = math.max(0, math.floor(prof.Cash + amount))
	pushAttributes(player)
	task.spawn(saveProfile, player)
end
ShopFunction.OnServerInvoke = function(player, action, id)
	local prof = profiles[player]
	if not prof or action ~= "buy" or type(id) ~= "string" then
		return false, "Shop unavailable."
	end
	local current = prof[id]
	local _, item = Config.ShopTier(id, 1)
	if not item or not current then
		return false, "Unknown item."
	end
	local nextTier = item.Tiers[current + 1]
	if not nextTier then
		return false, "Already maxed out."
	end
	if prof.Cash < nextTier.Price then
		return false, ("Not enough cash ($%d needed)."):format(nextTier.Price)
	end
	prof.Cash -= nextTier.Price
	prof[id] = current + 1
	pushAttributes(player)
	task.spawn(saveProfile, player)
	return true, "Bought " .. nextTier.Name .. "!"
end
do
	local terminal
	for _, d in zoo:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("ShopTerminal") then
			terminal = d
		end
	end
	if terminal then
		prompt(terminal, "Open Shop", "Wildcrest Supply", 0, 9).Triggered:Connect(function(player)
			OpenShop:FireClient(player)
		end)
	end
end
function round.spawnCash()
	for _, spot in CollectionService:GetTagged("CashSpot") do
		local value = math.random(Config.CashPickupMin or 10, Config.CashPickupMax or 40)
		local c = Instance.new("Part")
		c.Name = "Cash"
		c.Size = Vector3.new(1.4, 0.3, 0.8)
		c.Color = Color3.fromRGB(90, 170, 80)
		c.Material = Enum.Material.SmoothPlastic
		c.Anchored = true
		c.CanCollide = false
		c.CFrame = CFrame.new(spot.Position) * CFrame.Angles(0, math.random() * 6, 0)
		c.Parent = itemsFolder
		local glint = Instance.new("PointLight")
		glint.Color = c.Color
		glint.Range = 5
		glint.Brightness = 0.8
		glint.Parent = c
		prompt(c, "Take", ("Cash ($%d)"):format(value), 0).Triggered:Connect(function(player)
			if roster[player] and c.Parent then
				c:Destroy()
				round.addCash(player, value)
				Notify:FireClient(player, ("+$%d"):format(value), Color3.fromRGB(120, 255, 120))
			end
		end)
	end
end
Players.PlayerAdded:Connect(loadProfile)
for _, p in Players:GetPlayers() do
	task.spawn(loadProfile, p)
end
Players.PlayerRemoving:Connect(function(p)
	saveProfile(p)
	profiles[p] = nil
	loadedOk[p] = nil
end)
game:BindToClose(function()
	for p in profiles do
		saveProfile(p)
	end
end)
task.spawn(function()
	while true do
		task.wait(90)
		for p in profiles do
			saveProfile(p)
		end
	end
end)

-- Round setup -------------------------------------------------------------------------------
local blastTemplate = yard:FindFirstChild("BlastDoor"):Clone()

function resetRound()
	round.active = false
	round.ending = false
	round.choosing = false
	ReplicatedStorage:SetAttribute("DifficultyChoosing", false)
	clearMonsters()
	itemsFolder:ClearAllChildren()
	moneyBag = nil
	round.carrier = nil
	round.hasKeycard = false
	round.officeOpen = false
	round.safeOpen = false
	ReplicatedStorage:SetAttribute("MoneyCarrier", "")
	setPhase(0)
	setObjective("")
	setDoor(researchDoor, false)
	researchPrompt.ActionText = "Open"
	setDoor(keycardDoor, false)
	officePrompt.Enabled = true
	readerLight.Color = Color3.fromRGB(255, 30, 30)
	safeDoor.CFrame = safeHome
	if cellGlass then
		cellGlass.Transparency = 0.6
		cellGlass.CanCollide = true
	end
	for d, c in labColors do
		d.Color = c
	end
	ReplicatedStorage:SetAttribute("RadarReadyAt", 0)
	round.fuses = 0
	round.samples = {}
	ReplicatedStorage:SetAttribute("ZooFuses", 0)
	setSamples()
	setPower(false)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("HasStunner", nil)
		p:SetAttribute("StunCharges", nil)
	end
	if not yard:FindFirstChild("BlastDoor") then
		blastTemplate:Clone().Parent = yard
	end
	for _, spot in CollectionService:GetTagged("HideSpot") do
		spot:SetAttribute("Occupant", nil)
		local pr = spot:FindFirstChild("Door") and spot.Door:FindFirstChildOfClass("ProximityPrompt")
		if pr then
			pr.Enabled = true
		end
	end
end

function round.applyDifficulty(name, who)
	if not round.choosing or not Config.Difficulties[name] then
		return
	end
	round.choosing = false
	round.difficulty = name
	ReplicatedStorage:SetAttribute("Difficulty", name)
	ReplicatedStorage:SetAttribute("DifficultyChoosing", false)
	local d = D()
	for p, st in roster do
		st.lives = d.Lives
		p:SetAttribute("Lives", d.Lives)
	end
	notifyAll((who and (who.DisplayName .. " chose ") or "Difficulty: ") .. string.upper(name) .. ". Good luck.", d.Color)
	setObjective("Get the money from the Cash Office safe (back of the zoo).")
	local spawns = CollectionService:GetTagged("CrawlerSpawn")
	for i = 1, d.StartCrawlers or 1 do
		local sp = spawns[((i - 1) % #spawns) + 1]
		if sp then
			spawnMonster("Crawler", CFrame.new(sp.Position), "Zoo")
		end
	end
end
ChooseDifficulty.OnServerEvent:Connect(function(player, name)
	if roster[player] and type(name) == "string" then
		round.applyDifficulty(name, player)
	end
end)

local function beginRound()
	resetRound()
	table.clear(savedLives)
	round.id += 1
	round.active = true
	round.startTime = os.clock()
	setPhase(1)
	setupSafe()
	spawnKeycard()
	spawnPuzzleItems()
	round.spawnCash()
	for _, spot in CollectionService:GetTagged("BatterySpot") do
		spawnBattery(spot)
	end
	round.difficulty = nil
	round.choosing = true
	ReplicatedStorage:SetAttribute("Difficulty", "")
	ReplicatedStorage:SetAttribute("DifficultyChoosing", true)
	-- the intro cutscene (the Director's briefing) plays first; the pick timer starts after it
	local intro = (RunService:IsStudio() and workspace:GetAttribute("SkipIntro")) and 0 or (Config.IntroTime or 0)
	ReplicatedStorage:SetAttribute("IntroUntil", workspace:GetServerTimeNow() + intro)
	ReplicatedStorage:SetAttribute("DifficultyDeadline", workspace:GetServerTimeNow() + intro + Config.DifficultyChooseTime)
	setObjective("Choose a difficulty.")
	local id = round.id
	task.delay(intro + Config.DifficultyChooseTime, function()
		if round.active and round.id == id and round.choosing then
			round.applyDifficulty(Config.DefaultDifficulty, nil)
		end
	end)
end

local function addRider(player)
	if roster[player] then
		return
	end
	local lives = savedLives[player.UserId] or D().Lives
	savedLives[player.UserId] = nil
	roster[player] = { lives = lives, sprinting = false, moving = false, flashlight = false }
	player:SetAttribute("InGame", true)
	player:SetAttribute("Lives", lives)
	player:SetAttribute("Hidden", false)
	player:SetAttribute("CarryingMoney", false)
	task.spawn(applyInfinite, player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			removeFromRound(player, true)
		end)
	end
end

-- Joining: everyone who spawns in this place is in the round. A van's players
-- arrive together; anyone arriving mid-round joins the round in progress.
local function joinRound(player)
	-- arriving during the escape cutscene waits for the next round instead of cancelling it
	while round.ending and player.Parent do
		task.wait(0.5)
	end
	if not player.Parent or roster[player] then
		return
	end
	if not round.active then
		beginRound()
	end
	addRider(player)
	local char = player.Character
	if char then
		char:PivotTo(start.CFrame + Vector3.new(math.random(-4, 4), 3, 0))
	end
	if (ReplicatedStorage:GetAttribute("IntroUntil") or 0) <= workspace:GetServerTimeNow() then
		Notify:FireClient(player, "The van drops you at the gate. It's quiet. Too quiet.")
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
	removeFromRound(p)
	savedLives[p.UserId] = nil
	task.defer(function()
		if round.active and not round.ending and #inGamePlayers() == 0 then
			resetRound()
		end
	end)
end)

-- Studio-only test hook (never exists in a live server)
if RunService:IsStudio() then
	local dbg = Instance.new("BindableFunction")
	dbg.Name = "ZooDebug"
	dbg.Parent = ServerStorage
	dbg.OnInvoke = function(cmd, arg)
		if cmd == "monsters" then
			local out = {}
			for _, m in monsters do
				local wp = m.waypoints and m.waypoints[#m.waypoints]
				table.insert(out, ("%s state=%s feet=%s goal=%s pathing=%s idleIn=%.1f failedAgo=%.1f stunnedIn=%.1f area=%s bad=%d"):format(
					m.kind, tostring(m.state), tostring(m.feetPos), tostring(wp), tostring(m.pathing), (m.idleUntil or 0) - os.clock(),
					os.clock() - (m.failedAt or 0), (m.stunnedUntil or 0) - os.clock(), tostring(m.area), (function() local n = 0 for _ in (m.badGoals or {}) do n += 1 end return n end)()))
			end
			return table.concat(out, "\n")
		elseif cmd == "stunCharges" then
			for _, p in Players:GetPlayers() do
				p:SetAttribute("StunCharges", arg or 9)
			end
			return "ok"
		end
	end
end
-- ADMIN PANEL (the game's owner only - checked here on the server, not just in the UI) -------
local AdminRemote = remote("Admin")
local function isAdmin(player)
	return RunService:IsStudio() or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
end
AdminRemote.OnServerEvent:Connect(function(player, cmd, value)
	if not isAdmin(player) or type(cmd) ~= "string" then
		return
	end
	local function say(text)
		Notify:FireClient(player, "[ADMIN] " .. text, Color3.fromRGB(255, 220, 90))
	end
	if cmd == "god" then
		player:SetAttribute("AdminGod", value == true or nil)
		say(value and "God mode ON - nothing can see or catch you." or "God mode OFF.")
	elseif cmd == "freeze" then
		ReplicatedStorage:SetAttribute("AdminFreeze", value == true or nil)
		say(value and "Monsters FROZEN." or "Monsters unfrozen.")
	elseif cmd == "refill" then
		player:SetAttribute("HasStunner", true)
		player:SetAttribute("StunCharges", 8)
		player:SetAttribute("Flares", 5)
		AddBattery:FireClient(player, 100)
		say("Refilled: stun gun, flares, flashlight.")
	elseif cmd == "cash" then
		round.addCash(player, 1000)
		say("+$1000")
	elseif cmd == "clear" then
		clearMonsters()
		say("Monsters removed.")
	elseif cmd == "power" then
		setPower(true)
		say("Power ON.")
	elseif cmd == "samples" then
		for _, spot in CollectionService:GetTagged("SampleSpot") do
			giveSample(player, spot:GetAttribute("SampleId") or "Lab", "specimen jar")
		end
		for _, kind in { "Crawler", "Stalker", "Behemoth" } do
			giveSample(player, kind, kind:lower() .. " tissue")
		end
		for _, it in itemsFolder:GetChildren() do
			if it.Name == "Sample" then
				it:Destroy()
			end
		end
		say("All samples collected.")
	elseif cmd == "win" then
		if not round.ending then
			win()
		end
	end
end)
resetRound()
