-- Closing Time - Chapter 2: Last Call (the mall).
-- Goal: CAPTURE the Behemoth. Restore power (3 fuses -> generator) to open the
-- loading dock, bait the containment cage with freezer meat, and when the
-- Behemoth is inside, pull the lever. Then get back to the van.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("ZooConfig"))
local PlaceIds = require(ReplicatedStorage:WaitForChild("PlaceIds"))
local level = workspace:WaitForChild("Zoo") -- the mall (named Zoo so the shared client finds it)
local start = level:WaitForChild("Start")
local exitZone = level:WaitForChild("ExitZone")
local shutter = level:WaitForChild("DockShutter")
local cage = level:WaitForChild("CaptureCage")
local cageGate = cage:WaitForChild("Gate")
local cageInside = cage:WaitForChild("CageInside")
local baitPlate = cage:WaitForChild("BaitPlate")
local lever = cage:WaitForChild("Lever")
local generator = level:WaitForChild("Stores"):WaitForChild("MAINTENANCE"):WaitForChild("Generator")

local monstersFolder = level:FindFirstChild("Monsters") or Instance.new("Folder")
monstersFolder.Name = "Monsters"
monstersFolder.Parent = level
local itemsFolder = level:FindFirstChild("Items") or Instance.new("Folder")
itemsFolder.Name = "Items"
itemsFolder.Parent = level

-- Remotes (same names as Chapter 1, so the client is shared) ------------------
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
local StunRemote = remote("Stun")
local RadarPing = remote("RadarPing")
local ChooseDifficulty = remote("ChooseDifficulty")
local OpenShop = remote("OpenShop")
local RoarRemote = remote("Roar") -- server -> clients: screen shake (strength)
local FlareRemote = remote("Flare") -- client -> server (look direction)
local activeFlare -- { pos, untilT } the flare the Behemoth is drawn to
local ShopFunction = Instance.new("RemoteFunction")
ShopFunction.Name = "Shop"
ShopFunction.Parent = remotes

-- Round state ------------------------------------------------------------------------
local round = { active = false, phase = 0, startTime = 0, ending = false, id = 0 }
local roster = {}
local savedLives = {}
local function D()
	return Config.Difficulties[round.difficulty or Config.DefaultDifficulty] or Config.Difficulties.Normal
end
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
local function inBox(part, pos, pad)
	local rel = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2
	pad = pad or 0
	return math.abs(rel.X) <= h.X + pad and math.abs(rel.Z) <= h.Z + pad and math.abs(rel.Y) <= h.Y + pad + 4
end
local safeArea = level:FindFirstChild("SafeZone") and level.SafeZone:FindFirstChild("Area")
local function inSafeZone(pos)
	return safeArea ~= nil and inBox(safeArea, pos)
end

-- Monsters -----------------------------------------------------------------------------
local monsters = {}
local patrolPoints = {}
for _, p in CollectionService:GetTagged("PatrolPoint") do
	table.insert(patrolPoints, p.Position)
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
local function spawnMonster(kind, cframe)
	local model = ServerStorage.Monsters:FindFirstChild(kind):Clone()
	local hip = model:GetAttribute("HipHeight") or 3
	local scale = kind == "Behemoth" and Config.BehemothScale or 1
	if scale ~= 1 then
		model:ScaleTo(model:GetScale() * scale)
		hip *= scale
	end
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
	for _, j in model:GetDescendants() do
		if j:IsA("Motor6D") and (j:GetAttribute("Amp") or 0) > 0 then
			table.insert(joints, { motor = j, base = j.C0, amp = j:GetAttribute("Amp"), phase = j:GetAttribute("Phase") or 0 })
		end
	end
	local m = {
		kind = kind, cfg = cfg, model = model, root = model.PrimaryPart, hip = hip,
		state = "Patrol", waypoints = nil, wpIndex = 1, target = nil, lastSeenPos = nil, lastSeenTime = 0,
		idleUntil = os.clock() + 2, repathAt = 0, pathing = false, joints = joints, walkPhase = 0, yaw = 0,
		feetPos = cframe.Position,
		path = PathfindingService:CreatePath({ AgentRadius = cfg.AgentRadius, AgentHeight = cfg.AgentHeight, AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 4 }),
	}
	local snd = Config.MonsterSounds[kind]
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
		elseif m.boss then
			-- the arena is an open box: if pathfinding can't find a way, just walk straight at it
			m.waypoints = { goal }
			m.wpIndex = 1
		else
			m.waypoints = nil
			m.failedAt = os.clock()
			if m.state == "Patrol" then
				-- remember patrol spots it can't reach (B-00 doesn't fit through store doors)
				m.badGoals = m.badGoals or {}
				m.badGoals[goal] = true
			end
		end
	end)
end
local function pickPatrol(m)
	if #patrolPoints == 0 then
		return
	end
	local here = feet(m)
	local goal
	for _ = 1, 6 do
		local pts = ((m.boss or m.arena) and round.bossPoints) or patrolPoints
		goal = pts[math.random(#pts)]
		if (goal - here).Magnitude > 20 and not inSafeZone(goal) and not (m.badGoals and m.badGoals[goal]) then
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
local function perceive(m, player, st)
	if player:GetAttribute("AdminGod") then
		return nil
	end
	if st.hidden or os.clock() < (st.protectedUntil or 0) then
		return nil
	end
	local _, root, _, head = charParts(player)
	if not root or inSafeZone(root.Position) then
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

-- The Behemoth goes for the bait whenever it isn't chasing someone.
local function baitTarget()
	return baitPlate.Position + Vector3.new(0, 0.3, 4)
end

local baitModel -- the meat on the cage plate
local function think(m)
	if ReplicatedStorage:GetAttribute("AdminFreeze") then
		return
	end
	if m.captured or os.clock() < (m.stunnedUntil or 0) then
		m.lastMoveAt = os.clock()
		return
	end
	-- busy eating the bait: it ignores everything else
	if m.eatingUntil then
		m.lastMoveAt = os.clock()
		if os.clock() < m.eatingUntil and round.baitPlaced then
			return
		end
		m.eatingUntil = nil
		if round.baitPlaced then
			round.baitPlaced = false
			ReplicatedStorage:SetAttribute("BaitPlaced", false)
			if baitModel then
				baitModel:Destroy()
				baitModel = nil
			end
			notifyAll("It finished the bait and wandered off. Get more meat from the freezer!", Color3.fromRGB(255, 160, 80))
			round.spawnBait()
		end
		m.state = "Patrol"
	end
	-- watchdog: a monster that should be moving but hasn't for a while gets a fresh start
	m.lastMoveAt = m.lastMoveAt or os.clock()
	if os.clock() - m.lastMoveAt > 12 and os.clock() > (m.idleUntil or 0) then
		m.lastMoveAt = os.clock()
		m.pathing = false
		m.waypoints = nil
		m.badGoals = nil
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
	if m.growl and os.clock() > m.nextGrowl then
		m.growl.PlaybackSpeed = (Config.MonsterSounds[m.kind].Pitch or 1) * (0.9 + math.random() * 0.2)
		m.growl:Play()
		m.nextGrowl = os.clock() + (m.state == "Chase" and math.random(2, 4) or math.random(6, 12))
	end
	if m.kind == "Behemoth" then
		local ab = Config.Abilities.Behemoth
		-- ROAR: every so often it roars and learns roughly where the nearest player is
		m.nextRoar = m.nextRoar or (os.clock() + ab.RoarCooldown)
		if not bestSeen and os.clock() > m.nextRoar then
			local nearestPos, nd
			for _, player in inGamePlayers() do
				local st = roster[player]
				local _, r = charParts(player)
				if r and not st.hidden and os.clock() >= (st.protectedUntil or 0) and not inSafeZone(r.Position) then
					local d = (r.Position - m.root.Position).Magnitude
					if d < ab.RoarRange and (not nd or d < nd) then
						nearestPos, nd = r.Position, d
					end
				end
			end
			m.nextRoar = os.clock() + (nearestPos and ab.RoarCooldown or 4)
			if nearestPos then
				if m.growl then
					m.growl.PlaybackSpeed = 0.5
					m.growl:Play()
				end
				for _, p in inGamePlayers() do
					RoarRemote:FireClient(p, 0.6)
				end
				notifyAll("It ROARED... it knows roughly where you are.", Color3.fromRGB(255, 120, 90))
				heardPos = nearestPos + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
			end
		end
		-- FLARE: a burning flare pulls its attention (unless it's already chasing someone it can see)
		if activeFlare and not bestSeen and (activeFlare.pos - m.feetPos).Magnitude < Config.FlareRange then
			m.state = "Search"
			m.searchUntil = os.clock() + 2
			m.lastSeenPos = activeFlare.pos
			m.model:SetAttribute("Chasing", nil)
			if (m.feetPos - activeFlare.pos).Magnitude > 8 then
				if not m.waypoints and not m.pathing then
					computePath(m, activeFlare.pos)
				end
			else
				m.waypoints = nil
			end
			return
		end
	end
	if bestSeen then
		if m.state ~= "Chase" and m.growl then
			m.growl:Play()
			m.nextGrowl = os.clock() + 3
		end
		local _, root = charParts(bestSeen)
		m.model:SetAttribute("Chasing", bestSeen.Name)
		m.state = "Chase"
		m.target = bestSeen
		m.lastSeenPos = root.Position
		m.lastSeenTime = os.clock()
	elseif m.state == "Chase" then
		local st = m.target and roster[m.target]
		if st and st.hidden and not st.huntChecked then
			st.huntChecked = true
			local inside = st.hidden:FindFirstChild("Inside")
			local close = inside and (inside.Position - m.root.Position).Magnitude < 10 + m.hip * 0.5
			if close and os.clock() - m.lastSeenTime < 1.2 and math.random() < 0.5 then
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
	elseif heardPos and m.state ~= "Hunt" and m.state ~= "Bait" then
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
		local ab = Config.Abilities[m.kind]
		local flatTo = Vector3.new(root.Position.X - here.X, 0, root.Position.Z - here.Z)
		if ab and m.kind == "Crawler" and flatTo.Magnitude < ab.PounceRange and os.clock() > (m.nextPounce or 0) then
			m.pounceUntil = os.clock() + ab.PounceTime
			m.nextPounce = os.clock() + ab.PounceCooldown
			if m.growl then
				m.growl:Play()
			end
		elseif ab and m.kind == "Behemoth" and not m.charging and os.clock() > (m.nextCharge or 0)
			and flatTo.Magnitude > ab.ChargeMinRange and flatTo.Magnitude < ab.ChargeMaxRange and hasLOS(eyePos(m), root.Position) then
			m.charging = true
			m.chargeUntil = os.clock() + ab.ChargeTime
			m.chargeDir = flatTo.Unit
			m.nextCharge = os.clock() + ab.ChargeCooldown
			m.model:SetAttribute("Charging", true)
			if m.growl then
				m.growl:Play()
			end
		end
		if ab and m.kind == "Behemoth" and not m.charging and flatTo.Magnitude < ab.SlamRange and os.clock() > (m.nextSlam or 0) then
			-- GROUND SLAM: everyone close by is slowed for a moment
			m.nextSlam = os.clock() + ab.SlamCooldown
			m.stunnedUntil = os.clock() + 0.6
			for _, p in inGamePlayers() do
				local _, r = charParts(p)
				if r and (r.Position - m.feetPos).Magnitude < ab.SlamRadius and not roster[p].hidden then
					p:SetAttribute("SlowedUntil", workspace:GetServerTimeNow() + ab.SlamSlowTime)
					RoarRemote:FireClient(p, 1)
					Notify:FireClient(p, "GROUND SLAM - you're slowed!", Color3.fromRGB(255, 120, 90))
				end
			end
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
	elseif m.kind == "Behemoth" and round.baitPlaced and (m.state == "Patrol" or m.state == "Bait" or (m.state == "Search" and os.clock() > (m.searchUntil or 0))) then
		-- the smell of the bait pulls it to the cage
		m.state = "Bait"
		local goal = baitTarget()
		local flat = Vector3.new(goal.X - m.feetPos.X, 0, goal.Z - m.feetPos.Z)
		if flat.Magnitude < 4 then
			m.waypoints = nil
			m.eatingUntil = os.clock() + Config.BaitEatTime
			m.yaw = math.atan2(0, 1) -- face the back of the cage (-Z)
			notifyAll("It's in the cage, eating the bait... PULL THE LEVER!", Color3.fromRGB(255, 220, 90))
		elseif not m.waypoints and not m.pathing and os.clock() > m.repathAt then
			m.repathAt = os.clock() + 1
			computePath(m, goal)
		end
	elseif m.state == "Search" then
		if os.clock() > (m.searchUntil or 0) then
			m.state = "Patrol"
			m.waypoints = nil
		elseif not m.waypoints and not m.pathing then
			computePath(m, (m.lastSeenPos or feet(m)) + Vector3.new(math.random(-14, 14), 0, math.random(-14, 14)))
		end
	elseif m.state == "Patrol" or m.state == "Bait" then
		m.state = "Patrol"
		if not m.waypoints and not m.pathing and os.clock() > m.idleUntil and os.clock() > (m.failedAt or 0) + 2 then
			pickPatrol(m)
		end
	end
end

local arenaMin, arenaMax -- inside of the crash-site walls (set below)
local function step(m, dt)
	if ReplicatedStorage:GetAttribute("AdminFreeze") and not m.dead then
		return
	end
	if m.dead then
		return
	end
	if m.captured then
		-- thrashing in the cage
		m.root.CFrame = CFrame.new(m.feetPos + Vector3.new(0, m.hip, 0)) * CFrame.Angles(0, m.yaw + math.sin(os.clock() * 3) * 0.4, 0)
			* CFrame.Angles((math.random() - 0.5) * 0.05, 0, (math.random() - 0.5) * 0.05)
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
	local ab = Config.Abilities[m.kind]
	if ab and m.pounceUntil and os.clock() < m.pounceUntil then
		speed = ab.PounceSpeed
	end
	local moving = false
	if m.eatingUntil then
		-- head down at the bait
		m.root.CFrame = CFrame.new(m.feetPos + Vector3.new(0, m.hip * 0.9, 0)) * CFrame.Angles(0, m.yaw, 0) * CFrame.Angles(-0.25 + math.sin(os.clock() * 6) * 0.05, 0, 0)
		return
	end
	if m.charging then
		local here = feet(m)
		local hit = workspace:Raycast(here + Vector3.new(0, m.hip, 0), m.chargeDir * (m.cfg.AgentRadius + 3), rayParams())
			or workspace:Raycast(here + Vector3.new(0, 2.5, 0), m.chargeDir * (m.cfg.AgentRadius + 3), rayParams()) -- low obstacles (logs, the wreck)
		local nextFeet = here + m.chargeDir * ab.ChargeSpeed * dt
		if hit or os.clock() > m.chargeUntil or inSafeZone(nextFeet) then
			m.charging = false
			m.model:SetAttribute("Charging", nil)
			m.stunnedUntil = os.clock() + (hit and ab.DazeTime or ab.DazeTime * 0.5)
			if m.boss and hit and not m.dead then
				-- in the fight: dodge the charge so it slams into something -> a long daze = time to inject
				m.stunnedUntil = os.clock() + (Config.BossDazeTime or 3.5)
				notifyAll("B-00 smashed into the " .. ((hit.Instance and hit.Instance.Name == "ArenaWall") and "trees" or "wreck") .. " - it's DAZED! INJECT IT!", Color3.fromRGB(200, 160, 255))
			end
			m.waypoints = nil
		else
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
	if moving then
		m.lastMoveAt = os.clock()
	end
	-- out at the crash site nothing leaves the arena (paths can fail and fall back to a straight line)
	if (m.boss or m.arena) and arenaMin then
		local p = m.feetPos
		local cx = math.clamp(p.X, arenaMin.X, arenaMax.X)
		local cz = math.clamp(p.Z, arenaMin.Z, arenaMax.Z)
		if cx ~= p.X or cz ~= p.Z then
			m.feetPos = Vector3.new(cx, p.Y, cz)
			m.waypoints = nil
		end
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

-- Items --------------------------------------------------------------------------------
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

-- Power: lights, dock shutter, cage winch
local powerLights = {}
for _, d in level:GetDescendants() do
	if d:IsA("BasePart") and d:GetAttribute("PowerLight") then
		for _, l in d:GetChildren() do
			if l:IsA("Light") then
				table.insert(powerLights, l)
				l:SetAttribute("BaseBrightness", l.Brightness)
			end
		end
	end
end
local shutterHome = shutter:GetPivot()
local shutterPanel = shutter:FindFirstChild("DockShutter", true)
local shutterFull = shutterPanel.Size
local shutterTop = shutterPanel.Position.Y + shutterFull.Y / 2
local function rollShutter(k) -- 1 = closed, 0 = rolled up
	local h = math.max(0.6, shutterFull.Y * k)
	shutterPanel.Size = Vector3.new(shutterFull.X, h, shutterFull.Z)
	shutterPanel.Position = Vector3.new(shutterPanel.Position.X, shutterTop - h / 2, shutterPanel.Position.Z)
	for _, d in shutter:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "ShutterRib" then
			d.Transparency = d.Position.Y < shutterTop - h and 1 or 0
		end
	end
end
local gateHome = cageGate:GetPivot()
local function setPower(on)
	round.power = on
	ReplicatedStorage:SetAttribute("ZooPower", on)
	for i, l in powerLights do
		l.Enabled = on or i % 3 == 0
		l.Brightness = on and l:GetAttribute("BaseBrightness") or 0.3
	end
	if on then
		task.spawn(function()
			-- rolls up into the top of the doorway
			for i = 1, 30 do
				rollShutter(1 - i / 30)
				task.wait(0.05)
			end
		end)
		for _, d in shutter:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
	else
		rollShutter(1)
		for _, d in shutter:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = d.Name == "DockShutter"
			end
		end
	end
end

local fuseCount = 0
local function spawnFuses()
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
			fuseCount += 1
			ReplicatedStorage:SetAttribute("ZooFuses", fuseCount)
			notifyAll(("%s found a fuse (%d/%d)"):format(player.DisplayName, fuseCount, Config.FusesNeeded), Color3.fromRGB(255, 190, 90))
		end)
	end
end
local genPrompt = prompt(generator, "Insert Fuses", "Generator", 1.5, 10)
genPrompt.Triggered:Connect(function(player)
	if not roster[player] or round.power or round.choosing then
		return
	end
	if fuseCount < Config.FusesNeeded then
		Notify:FireClient(player, ("The generator needs %d fuses. You have %d."):format(Config.FusesNeeded, fuseCount))
		return
	end
	setPower(true)
	setPhase(2)
	notifyAll("POWER RESTORED. The loading dock is open.", Color3.fromRGB(120, 255, 140))
	setObjective("Bait the cage: take meat from the food court freezer and put it on the plate in the cage (loading dock).")
end)

-- Bait (freezer meat) - carried by one player, placed on the cage plate
function round.spawnBait()
	local spot = CollectionService:GetTagged("BaitSpot")[1]
	if not spot or itemsFolder:FindFirstChild("Bait") then
		return
	end
	local meat = itemPart("Bait", Vector3.new(1.6, 0.9, 1.2), Color3.fromRGB(170, 40, 50), CFrame.new(spot.Position))
	meat.Material = Enum.Material.SmoothPlastic
	prompt(meat, "Take", "Raw Meat (bait)", 0.4).Triggered:Connect(function(player)
		if not roster[player] or not meat.Parent or player:GetAttribute("CarryingMoney") then
			return
		end
		meat:Destroy()
		player:SetAttribute("CarryingMoney", true) -- (shared "carrying" flag: you walk a bit slower)
		round.baitCarrier = player
		ReplicatedStorage:SetAttribute("MoneyCarrier", "") -- not money; keeps the money label empty
		Notify:FireClient(player, "Got the bait. Put it on the plate in the cage on the loading dock.", Color3.fromRGB(255, 200, 120))
	end)
end
local platePrompt = prompt(baitPlate, "Place Bait", "Cage Plate", 0.8, 9)
platePrompt.Triggered:Connect(function(player)
	if not roster[player] then
		return
	end
	if not round.power then
		Notify:FireClient(player, "The cage has no power yet.")
		return
	end
	if round.baitCarrier ~= player then
		Notify:FireClient(player, "You need bait - raw meat from the food court freezer.")
		return
	end
	if round.baitPlaced or round.captured or round.trapped then
		return
	end
	if not round.baitLaced then
		Notify:FireClient(player, "Plain meat won't keep B-00 still. Lace it with tranquilizer at the food court PREP COUNTER first.", Color3.fromRGB(255, 180, 120))
		return
	end
	round.baitCarrier = nil
	round.baitLaced = false
	ReplicatedStorage:SetAttribute("BaitLaced", false)
	player:SetAttribute("CarryingMoney", false)
	round.baitPlaced = true
	ReplicatedStorage:SetAttribute("BaitPlaced", true)
	baitModel = itemPart("BaitOnPlate", Vector3.new(1.6, 0.9, 1.2), Color3.fromRGB(170, 40, 50), baitPlate.CFrame * CFrame.new(0, 0.6, 0))
	baitModel.Material = Enum.Material.SmoothPlastic
	notifyAll("Bait placed. The Behemoth can smell it... get out of the cage and wait by the lever.", Color3.fromRGB(255, 200, 120))
	setObjective(round.handleFixed and "Wait for the Behemoth to walk into the cage, then PULL THE LEVER."
		or "Bait's set - but the cage lever has no handle! Find the WINCH HANDLE (Toy Town, Volt or Pixel Arcade).")
end)

-- The lever drops the cage gate
local leverBox = lever:WaitForChild("Box")
local leverLight = lever:WaitForChild("Light")
local winchReadyAt = 0
local leverPrompt = prompt(leverBox, "Pull Lever", "Cage Gate", 0.5, 9)
local function behemoth()
	for _, m in monsters do
		if m.kind == "Behemoth" then
			return m
		end
	end
end
leverPrompt.Triggered:Connect(function(player)
	if not roster[player] or round.captured or round.trapped then
		return
	end
	if not round.power then
		Notify:FireClient(player, "No power to the cage winch.")
		return
	end
	if not round.handleFixed then
		Notify:FireClient(player, "The lever's handle is missing! Find the WINCH HANDLE somewhere in the mall.")
		return
	end
	if round.trapped then
		return
	end
	if os.clock() < winchReadyAt then
		Notify:FireClient(player, ("The winch is still resetting... %d s"):format(math.ceil(winchReadyAt - os.clock())))
		return
	end
	-- anyone standing inside the cage dives out under the gate as it falls
	for _, p in inGamePlayers() do
		local _, r = charParts(p)
		if r and inBox(cageInside, r.Position) then
			r.CFrame = CFrame.new(cageInside.Position.X + math.random(-4, 4), r.Position.Y, cageInside.Position.Z + cageInside.Size.Z / 2 + 6)
			Notify:FireClient(p, "You dive out under the gate as it slams down!", Color3.fromRGB(255, 220, 120))
		end
	end
	-- drop the gate
	for i = 1, 12 do
		cageGate:PivotTo(gateHome * CFrame.new(0, -17 * i / 12, 0))
		task.wait(0.02)
	end
	local b = behemoth()
	if b and inBox(cageInside, b.feetPos + Vector3.new(0, 2, 0)) then
		-- TRAPPED: the gate is down, but it has to be clamped shut
		round.trapped = true
		b.captured = true -- (stops its AI; it thrashes in place)
		b.eatingUntil = nil
		b.model:SetAttribute("Chasing", nil)
		b.model:SetAttribute("Trapped", true)
		if b.growl then
			b.growl:Play()
		end
		leverLight.Color = Color3.fromRGB(255, 200, 40)
		setPhase(3)
		round.setClampPrompts(true)
		notifyAll("IT'S IN! Now LOCK BOTH CAGE CLAMPS - it's slamming the bars!", Color3.fromRGB(255, 220, 90))
		setObjective("Lock BOTH cage clamps (hold at each front corner). Its slams knock you off - time it, or stun it first!")
		round.wakeCrawlers()
	else
		notifyAll("Missed - it wasn't inside! The winch needs " .. Config.WinchReset .. " seconds to reset.", Color3.fromRGB(255, 120, 90))
		winchReadyAt = os.clock() + Config.WinchReset
		leverLight.Color = Color3.fromRGB(255, 150, 40)
		task.delay(Config.WinchReset, function()
			if not round.captured then
				cageGate:PivotTo(gateHome)
				leverLight.Color = Color3.fromRGB(255, 60, 40)
			end
		end)
	end
end)

-- Winch handle: the lever is missing its handle --------------------------------------------
local leverHandle = lever:WaitForChild("Handle")
local handlePrompt = prompt(leverHandle, "Attach Handle", "Cage Lever", 1.5, 9) -- (its own part: one prompt per part)
handlePrompt.Enabled = false
local function setHandleFixed(on)
	round.handleFixed = on
	ReplicatedStorage:SetAttribute("HandleFixed", on)
	leverHandle.Transparency = on and 0 or 1
	leverPrompt.Enabled = on
	handlePrompt.Enabled = not on
end
function round.spawnHandle()
	local spots = CollectionService:GetTagged("HandleSpot")
	if #spots == 0 or itemsFolder:FindFirstChild("WinchHandle") then
		return
	end
	local spot = spots[math.random(1, #spots)]
	local h = itemPart("WinchHandle", Vector3.new(0.5, 2.4, 0.5), Color3.fromRGB(255, 120, 40), CFrame.new(spot.Position) * CFrame.Angles(0, 0, math.pi / 2.4))
	prompt(h, "Take", "Winch Handle", 0.3).Triggered:Connect(function(player)
		if not roster[player] or not h.Parent then
			return
		end
		h:Destroy()
		player:SetAttribute("HasHandle", true)
		Notify:FireClient(player, "Winch handle! Attach it to the cage lever on the loading dock.", Color3.fromRGB(255, 170, 90))
	end)
end
handlePrompt.Triggered:Connect(function(player)
	if not roster[player] or round.handleFixed then
		return
	end
	if not player:GetAttribute("HasHandle") then
		Notify:FireClient(player, "The handle is missing. Find the WINCH HANDLE (Toy Town, Volt or Pixel Arcade).")
		return
	end
	player:SetAttribute("HasHandle", nil)
	setHandleFixed(true)
	notifyAll("Winch repaired - the cage lever works.", Color3.fromRGB(140, 255, 160))
	if round.baitPlaced and not round.trapped then
		setObjective("Wait for the Behemoth to walk into the cage, then PULL THE LEVER.")
	end
end)

-- Tranquilizer + the prep counter -----------------------------------------------------
function round.spawnSedative()
	local spots = CollectionService:GetTagged("SedativeSpot")
	if #spots == 0 or round.sedative or itemsFolder:FindFirstChild("Sedative") then
		return
	end
	local spot = spots[math.random(1, #spots)]
	local v = itemPart("Sedative", Vector3.new(0.5, 1, 0.5), Color3.fromRGB(180, 120, 255), CFrame.new(spot.Position), Enum.PartType.Cylinder)
	prompt(v, "Take", "Animal Tranquilizer", 0.3).Triggered:Connect(function(player)
		if not roster[player] or not v.Parent then
			return
		end
		v:Destroy()
		round.sedative = true
		ReplicatedStorage:SetAttribute("SedativeFound", true)
		notifyAll(player.DisplayName .. " found the animal tranquilizer! Lace the freezer meat with it at the PREP COUNTER.", Color3.fromRGB(200, 160, 255))
	end)
end
local prepBoard = level:WaitForChild("CaptureProps"):WaitForChild("PrepBoard")
local prepPrompt = prompt(prepBoard, "Lace Meat", "Prep Counter", 2, 8)
prepPrompt.Triggered:Connect(function(player)
	if not roster[player] then
		return
	end
	if round.baitCarrier ~= player then
		Notify:FireClient(player, "Bring the raw meat from the freezer here.")
		return
	end
	if not round.sedative then
		Notify:FireClient(player, "You need the animal tranquilizer. Check the medicine cabinets (Pet Palace, Security, Maintenance).")
		return
	end
	if round.baitLaced then
		return
	end
	round.baitLaced = true
	ReplicatedStorage:SetAttribute("BaitLaced", true)
	Notify:FireClient(player, "Meat laced. Now put it on the cage plate (loading dock).", Color3.fromRGB(200, 160, 255))
end)

-- Cage clamps: both must be locked while it thrashes ------------------------------------------
local clampModels = { cage:WaitForChild("Clamps"):WaitForChild("ClampL"), cage.Clamps:WaitForChild("ClampR") }
local clampPrompts = {}
round.clamps = {}
local function clampCount()
	local n = 0
	for _, v in round.clamps do
		if v then
			n += 1
		end
	end
	return n
end
local function paintClamp(c, locked)
	local l = c:FindFirstChild("Light")
	if l then
		l.Color = locked and Color3.fromRGB(60, 255, 90) or Color3.fromRGB(255, 60, 40)
		local pl = l:FindFirstChildOfClass("PointLight")
		if pl then
			pl.Color = l.Color
		end
	end
	local bolt = c:FindFirstChild("Bolt")
	if bolt then
		local home = bolt:GetAttribute("Home") or bolt.CFrame
		bolt:SetAttribute("Home", home)
		local inward = c.Box.Position.X > 0 and -1 or 1
		bolt.CFrame = locked and (home + Vector3.new(inward * 1.2, 0, 0)) or home
	end
end
function round.setClampPrompts(on)
	for i, pr in clampPrompts do
		pr.Enabled = on and not round.clamps[i]
	end
end
for i, c in clampModels do
	local pr = prompt(c.Box, "Lock Clamp", i == 1 and "Left Clamp" or "Right Clamp", Config.ClampHoldTime or 3, 7)
	pr.Enabled = false
	clampPrompts[i] = pr
	pr.Triggered:Connect(function(player)
		if not roster[player] or not round.trapped or round.clamps[i] then
			return
		end
		round.clamps[i] = true
		pr.Enabled = false
		paintClamp(c, true)
		local n = clampCount()
		ReplicatedStorage:SetAttribute("ClampsLocked", n)
		if n < #clampModels then
			notifyAll(("Clamp locked (%d/%d)."):format(n, #clampModels), Color3.fromRGB(140, 255, 160))
			return
		end
		-- fully secured
		round.captured = true
		local b = behemoth()
		if b then
			b.model:SetAttribute("Trapped", nil)
			b.model:SetAttribute("Captured", true)
		end
		leverLight.Color = Color3.fromRGB(60, 255, 90)
		setPhase(4)
		notifyAll("B-00 IS SECURED! Radio Wildcrest from the SECURITY office for pickup.", Color3.fromRGB(120, 255, 140))
		setObjective("Use the radio in the SECURITY office to call Wildcrest for pickup.")
	end)
end
-- the slams: every few seconds, knocks anyone near the cage off the clamps
task.spawn(function()
	while true do
		task.wait(Config.ThrashMin + math.random() * (Config.ThrashMax - Config.ThrashMin))
		local b = behemoth()
		if round.active and round.trapped and not round.captured and b and os.clock() >= (b.stunnedUntil or 0) then
			if b.growl then
				b.growl:Play()
			end
			for _, p in inGamePlayers() do
				local _, root = charParts(p)
				if root then
					local d = (root.Position - cageInside.Position).Magnitude
					if d < Config.ThrashRange then
						p:SetAttribute("SlowedUntil", workspace:GetServerTimeNow() + 1.5)
						RoarRemote:FireClient(p, 0.9)
						Notify:FireClient(p, "B-00 SLAMS THE BARS! You lost your grip.", Color3.fromRGB(255, 110, 90))
					else
						RoarRemote:FireClient(p, 0.25)
					end
				end
			end
			-- cancel any clamp holds in progress
			for i, pr in clampPrompts do
				if not round.clamps[i] then
					pr.Enabled = false
				end
			end
			task.delay(0.9, function()
				if round.trapped and not round.captured then
					round.setClampPrompts(true)
				end
			end)
		end
	end
end)

-- The alarm wakes the Crawlers when the gate drops
function round.wakeCrawlers()
	if Config.NoCrawlers then
		return
	end
	local spawns = CollectionService:GetTagged("CrawlerSpawn")
	local n = D().StartCrawlers or 2
	for i = 1, math.min(n, #spawns) do
		local id = round.id
		task.delay(i * 2.5, function()
			if round.active and round.id == id and not round.ending then
				spawnMonster("Crawler", CFrame.new(spawns[i].Position))
			end
		end)
	end
	notifyAll("The alarm is waking things up... CRAWLERS are coming.", Color3.fromRGB(255, 90, 80))
end

-- Security radio: call the pickup ------------------------------------------------------
local radioPart = level.CaptureProps:WaitForChild("Radio")
local radioLight = level.CaptureProps:WaitForChild("RadioLight")
local radioPrompt = prompt(radioPart, "Call Wildcrest", "Radio", Config.RadioHoldTime or 3, 8)
radioPrompt.Triggered:Connect(function(player)
	if not roster[player] or round.called then
		return
	end
	if not round.captured then
		Notify:FireClient(player, "Static... \"Wildcrest here. Call back when B-00 is IN THE CAGE.\"")
		return
	end
	round.called = true
	ReplicatedStorage:SetAttribute("PickupCalled", true)
	radioLight.Color = Color3.fromRGB(60, 255, 90)
	radioPrompt.Enabled = false
	notifyAll("\"Copy. Winch the cage into your van and bring it to HQ. Don't stop for anything.\"", Color3.fromRGB(140, 220, 255))
	setObjective("Get back to the van in the parking lot - the cage gets loaded in the back.")
end)

-- Stun gun + cartridges
local function spawnStunGun()
	local sg = CollectionService:GetTagged("StunGunSpot")[1]
	if not sg then
		return
	end
	local gun = itemPart("StunGun", Vector3.new(0.5, 0.8, 1.8), Color3.fromRGB(80, 170, 255), CFrame.new(sg.Position))
	prompt(gun, "Take", "Stun Gun", 0.3).Triggered:Connect(function(player)
		if not roster[player] or player:GetAttribute("HasStunner") then
			return
		end
		local tier = Config.ShopTier("Stun", player:GetAttribute("StunTier") or 1)
		player:SetAttribute("HasStunner", true)
		player:SetAttribute("StunCharges", (D().StunCharges or Config.StunCharges) + (tier and tier.Bonus or 0))
		Notify:FireClient(player, "Stun gun! Press [Q] to zap a monster in front of you.", Color3.fromRGB(140, 220, 255))
	end)
end
local function spawnCartridge(spot)
	local id = round.id
	local c = itemPart("StunCartridge", Vector3.new(0.5, 0.5, 0.9), Color3.fromRGB(80, 170, 255), CFrame.new(spot.Position))
	prompt(c, "Take", "Stun Cartridge", 0).Triggered:Connect(function(player)
		if not roster[player] or not c.Parent then
			return
		end
		if not player:GetAttribute("HasStunner") then
			Notify:FireClient(player, "A stun cartridge... you need the stun gun from the Security office.")
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
local function spawnBattery(spot)
	local id = round.id
	local b = itemPart("Battery", Vector3.new(0.6, 1.2, 0.6), Color3.fromRGB(240, 200, 40), CFrame.new(spot.Position))
	prompt(b, "Take", "Battery", 0).Triggered:Connect(function(player)
		if not roster[player] or not b.Parent then
			return
		end
		b:Destroy()
		AddBattery:FireClient(player, Config.BatteryPickup)
		task.delay(Config.BatteryRespawn, function()
			if round.active and round.id == id then
				spawnBattery(spot)
			end
		end)
	end)
end

local lastStun = {}
StunRemote.OnServerEvent:Connect(function(player, look)
	local st = roster[player]
	local _, root, _, head = charParts(player)
	if not st or not root or st.hidden or round.ending or typeof(look) ~= "Vector3" or not player:GetAttribute("HasStunner") then
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
		if (not m.captured or (m.kind == "Behemoth" and round.trapped and not round.captured)) and d <= Config.StunRange + m.hip * 0.5 and look:Dot(to.Unit) > 0.75 and d < (bestD or math.huge)
			and workspace:Raycast(from, to, rayParams()) == nil then
			best, bestD = m, d
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
	m.eatingUntil = nil
	m.state = "Search"
	m.searchUntil = os.clock() + dur + 4
	m.lastSeenPos = root.Position
	m.target = nil
	m.waypoints = nil
	m.model:SetAttribute("Chasing", nil)
	m.model:SetAttribute("Stunned", true)
	local fx = Instance.new("ParticleEmitter")
	fx.Color = ColorSequence.new(Color3.fromRGB(120, 200, 255))
	fx.LightEmission = 1
	fx.Size = NumberSequence.new(0.6, 0)
	fx.Speed = NumberRange.new(6, 12)
	fx.SpreadAngle = Vector2.new(180, 180)
	fx.Lifetime = NumberRange.new(0.2, 0.4)
	fx.Rate = 60
	fx.Parent = m.root
	Notify:FireClient(player, "Stunned!", Color3.fromRGB(140, 220, 255))
	task.delay(dur, function()
		if m.model.Parent then
			m.model:SetAttribute("Stunned", nil)
			fx:Destroy()
		end
	end)
end)

-- Player ability: FLARES (G) - the Behemoth goes to stare at the light ----------------------
FlareRemote.OnServerEvent:Connect(function(player, look)
	local st = roster[player]
	local _, root, _, head = charParts(player)
	if not st or not root or st.hidden or round.ending or typeof(look) ~= "Vector3" then
		return
	end
	local n = player:GetAttribute("Flares") or 0
	if n <= 0 or os.clock() - (st.lastFlare or 0) < 2 then
		return
	end
	st.lastFlare = os.clock()
	player:SetAttribute("Flares", n - 1)
	look = look.Magnitude > 0 and look.Unit or root.CFrame.LookVector
	local from = (head or root).Position
	local hit = workspace:Raycast(from, look * 28, rayParams())
	local pos = hit and (hit.Position - look * 1) or (from + look * 28)
	local down = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), rayParams())
	if down then
		pos = down.Position + Vector3.new(0, 0.3, 0)
	end
	local f = itemPart("Flare", Vector3.new(0.4, 0.4, 1.4), Color3.fromRGB(255, 60, 40), CFrame.new(pos))
	local l = f:FindFirstChildOfClass("PointLight")
	l.Range = 30
	l.Brightness = 4
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 120, 60))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.4, 0)
	sparks.Speed = NumberRange.new(3, 7)
	sparks.Lifetime = NumberRange.new(0.4, 0.9)
	sparks.Rate = 40
	sparks.Acceleration = Vector3.new(0, 6, 0)
	sparks.Parent = f
	Debris:AddItem(f, Config.FlareTime)
	activeFlare = { pos = pos, untilT = os.clock() + Config.FlareTime }
	if round.boss and round.flareHit then
		round.flareHit(pos, player, from)
	end
	Notify:FireClient(player, "Flare out!", Color3.fromRGB(255, 140, 90))
end)

-- Radar -----------------------------------------------------------------------------------------
local radar = level:FindFirstChild("RadarStation")
if radar and radar:FindFirstChild("Console") then
	prompt(radar.Console, "Activate Radar", "Mall Radar", 1, 9).Triggered:Connect(function(player)
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
		notifyAll(player.DisplayName .. " used the radar!", Color3.fromRGB(120, 255, 140))
	end)
end

-- Notes ----------------------------------------------------------------------------------------
for _, n in CollectionService:GetTagged("Note") do
	prompt(n, "Read", "Note", 0, 7).Triggered:Connect(function(player)
		ShowNote:FireClient(player, n:GetAttribute("NoteText") or "")
	end)
end

-- Hiding --------------------------------------------------------------------------------------
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
	local door, inside = spot:FindFirstChild("Door"), spot:FindFirstChild("Inside")
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

-- Game passes (from Chapter 1) ----------------------------------------------------------------------
local passCache = {}
local function owns(player, id)
	if not id or id == 0 then
		return false
	end
	local key = player.UserId .. ":" .. id
	if passCache[key] == nil then
		local ok, yes = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		passCache[key] = ok and yes or false
	end
	return passCache[key]
end
local function applyPasses(player)
	player:SetAttribute("NokiaFlashlight", owns(player, Config.NokiaFlashlightPassId))
	local inf = owns(player, Config.InfiniteLivesPassId)
	player:SetAttribute("InfiniteLives", inf)
	if roster[player] then
		roster[player].infinite = inf
	end
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased then
		passCache[player.UserId .. ":" .. passId] = true
		applyPasses(player)
	end
end)

-- Cash, saved upgrades, shop ----------------------------------------------------------------------
local profileStore
pcall(function()
	profileStore = DataStoreService:GetDataStore("ZooProfile_v1")
end)
local profiles, loadedOk = {}, {}
local function pushAttributes(player)
	local prof = profiles[player]
	if prof then
		player:SetAttribute("Cash", prof.Cash)
		if player:GetAttribute("CashAtJoin") == nil then
			player:SetAttribute("CashAtJoin", prof.Cash)
		end
		player:SetAttribute("FlashTier", prof.Flashlight)
		player:SetAttribute("ShoeTier", prof.Shoes)
		player:SetAttribute("StunTier", prof.Stun)
	end
end
local function saveProfile(player)
	local prof = profiles[player]
	if prof and loadedOk[player] and profileStore then
		pcall(function()
			profileStore:SetAsync("p_" .. player.UserId, prof)
		end)
	end
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
	loadedOk[player] = ok
	pushAttributes(player)
end
local function addCash(player, amount)
	local prof = profiles[player]
	if prof then
		prof.Cash = math.max(0, math.floor(prof.Cash + amount))
		pushAttributes(player)
		task.spawn(saveProfile, player)
	end
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
for _, d in level:GetDescendants() do
	if d:IsA("BasePart") and d:GetAttribute("ShopTerminal") then
		prompt(d, "Open Shop", "Wildcrest Supply", 0, 9).Triggered:Connect(function(player)
			OpenShop:FireClient(player)
		end)
	end
end
local function spawnCash()
	for _, spot in CollectionService:GetTagged("CashSpot") do
		local value = math.random(Config.CashPickupMin, Config.CashPickupMax)
		local c = itemPart("Cash", Vector3.new(1.4, 0.3, 0.8), Color3.fromRGB(90, 170, 80), CFrame.new(spot.Position) * CFrame.Angles(0, math.random() * 6, 0))
		c.Material = Enum.Material.SmoothPlastic
		prompt(c, "Take", ("Cash ($%d)"):format(value), 0).Triggered:Connect(function(player)
			if roster[player] and c.Parent then
				c:Destroy()
				addCash(player, value)
				Notify:FireClient(player, ("+$%d"):format(value), Color3.fromRGB(120, 255, 120))
			end
		end)
	end
end
Players.PlayerAdded:Connect(loadProfile)
for _, p in Players:GetPlayers() do
	task.spawn(loadProfile, p)
end
game:BindToClose(function()
	for p in profiles do
		saveProfile(p)
	end
end)

-- Catching, leaving, the cage timer, winning ----------------------------------------------------
local resetRound

local function removeFromRound(player, keepLives)
	if not roster[player] then
		return
	end
	savedLives[player.UserId] = keepLives and roster[player].lives or nil
	unhide(player, false)
	if round.baitCarrier == player then
		round.baitCarrier = nil
		player:SetAttribute("CarryingMoney", false)
		round.baitLaced = false
		ReplicatedStorage:SetAttribute("BaitLaced", false)
		round.spawnBait()
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
	if not keepLives and round.active and #inGamePlayers() == 0 and not round.ending then
		resetRound()
	end
end

local function sendToLobby(list, completedChapter)
	for _, p in list do
		removeFromRound(p)
	end
	if not RunService:IsStudio() and PlaceIds.Lobby ~= 0 then
		local ok, err = true, nil
		for _, p in list do
			local earned = math.clamp((p:GetAttribute("Cash") or 0) - (p:GetAttribute("CashAtJoin") or (p:GetAttribute("Cash") or 0)), 0, 2000)
			local ok1, err1 = pcall(function()
				local options = Instance.new("TeleportOptions")
				options:SetTeleportData({ Completed = completedChapter, Earned = earned, From = 2 })
				TeleportService:TeleportAsync(PlaceIds.Lobby, { p }, options)
			end)
			if not ok1 then
				ok, err = false, err1
			end
		end
		if not ok then
			warn("Teleport to lobby failed: " .. tostring(err))
			for _, p in list do
				p:Kick("Couldn't get back to the lobby. Please rejoin Closing Time.")
			end
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
	local _, root = charParts(player)
	if root and inSafeZone(root.Position) then
		return
	end
	st.beingCaught = true
	if st.hidden then
		unhide(player, true)
	end
	if round.baitCarrier == player then
		round.baitCarrier = nil
		player:SetAttribute("CarryingMoney", false)
		round.baitLaced = false
		ReplicatedStorage:SetAttribute("BaitLaced", false)
		round.spawnBait()
		Notify:FireClient(player, "You dropped the bait - it's back in the freezer.")
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
			r2.CFrame = (round.respawnCF or start.CFrame) + Vector3.new(math.random(-3, 3), 3, 0)
		end
		st.protectedUntil = os.clock() + D().Protect
		player:SetAttribute("Protected", true)
		task.delay(D().Protect, function()
			if player.Parent then
				player:SetAttribute("Protected", nil)
			end
		end)
		-- no spawn camping
		for _, mon in monsters do
			local home = (round.respawnCF or start.CFrame).Position
			if not mon.captured and (mon.feetPos - home).Magnitude < (mon.boss and 40 or 70) then
				local far, farD = nil, 0
				for _, pt in ((mon.boss or mon.arena) and round.bossPoints) or patrolPoints do
					local d = (pt - home).Magnitude
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
	clearMonsters()
	for _, p in inGamePlayers() do
		local _, root = charParts(p)
		if root then
			root.Anchored = true
		end
	end
	local reward = Config.EscapeReward[round.difficulty or "Normal"] or 350
	for _, p in inGamePlayers() do
		addCash(p, reward)
		local mvp, mvpD = nil, 0
		for name, d in round.damage or {} do
			if d > mvpD then
				mvp, mvpD = name, d
			end
		end
		Escaped:FireClient(p, secs, 1, 1, round.difficulty, reward, mvp and ("MVP: %s - %d damage to B-00"):format(mvp, mvpD) or nil)
	end
	setObjective("B-00 captured. Mission complete.")
	task.delay(Config.ReturnToLobbyDelay, function()
		local list = inGamePlayers()
		resetRound()
		sendToLobby(list, 2) -- tells the lobby: Chapter 2 beaten
	end)
end

-- FINALE: the van ride -> it chokes you through the bars -> the crash -> KILL IT -------------
local ChokeRemote = remote("Choke") -- server->client "start"; client->server result (true/false)
local CrashRemote = remote("Crash") -- server->client: play the crash
local crashSite = workspace:WaitForChild("CrashSite")
local puddle = crashSite:WaitForChild("FuelPuddle")
local puddleR = puddle.Size.Y / 2
local crashSpawns = CollectionService:GetTagged("CrashSpawn")
do
	local lo, hi = Vector3.new(math.huge, 0, math.huge), Vector3.new(-math.huge, 0, -math.huge)
	for _, w in crashSite:GetDescendants() do
		if w:IsA("BasePart") and w.Name == "ArenaWall" then
			lo = Vector3.new(math.min(lo.X, w.Position.X), 0, math.min(lo.Z, w.Position.Z))
			hi = Vector3.new(math.max(hi.X, w.Position.X), 0, math.max(hi.Z, w.Position.Z))
		end
	end
	if lo.X < hi.X then
		local pad = 6 -- wall half-thickness + its body
		arenaMin = Vector3.new(lo.X + pad, 0, lo.Z + pad)
		arenaMax = Vector3.new(hi.X - pad, 0, hi.Z - pad)
	end
end
round.bossPoints = {}
for _, sp in CollectionService:GetTagged("BossPoint") do
	table.insert(round.bossPoints, sp.Position)
end

function round.startRide()
	if round.ride or round.crashed or round.ending then
		return
	end
	round.ride = true
	setPhase(5)
	ReplicatedStorage:SetAttribute("Alarm", false)
	setObjective("On the road to Wildcrest HQ. B-00 is in the cage behind you...")
	clearMonsters() -- the crawlers stay at the mall; B-00 is in the van
	for _, p in inGamePlayers() do
		local st = roster[p]
		if st and st.hidden then
			unhide(p, false)
		end
		local _, root = charParts(p)
		if root then
			root.Anchored = true
		end
		p:SetAttribute("CarryingMoney", false)
		st.chokeStart = os.clock()
		ChokeRemote:FireClient(p, "start", true)
	end
	-- never hang: if nobody breaks free (lag, a crashed client...), the van crashes anyway
	local id = round.id
	task.delay(Config.RideTimeout or 45, function()
		if round.id == id and round.ride and not round.crashed and not round.ending then
			round.crash()
		end
	end)
end

ChokeRemote.OnServerEvent:Connect(function(player, ok)
	local st = roster[player]
	if not st or not round.ride or round.crashed or round.ending then
		return
	end
	if os.clock() - (st.chokeStart or 0) < 3 then
		return -- too fast to be real
	end
	st.chokeStart = os.clock() + 999 -- one result per attempt
	if ok == true then
		round.crash()
		return
	end
	if not st.infinite then
		st.lives -= 1
		player:SetAttribute("Lives", st.lives)
	end
	if st.lives <= 0 then
		notifyAll(player.DisplayName .. " blacked out... and never woke up.", Color3.fromRGB(255, 80, 80))
		sendToLobby({ player })
		return
	end
	task.delay(2.5, function()
		if round.ride and not round.crashed and roster[player] then
			st.chokeStart = os.clock()
			ChokeRemote:FireClient(player, "start", false)
		end
	end)
end)

function round.joinFinale(player)
	local st = roster[player]
	if not st then
		return
	end
	local _, root = charParts(player)
	if round.boss and round.respawnCF then
		if root then
			root.Anchored = false
			root.CFrame = round.respawnCF + Vector3.new(math.random(-4, 4), 3, 0)
		end
		local tier = Config.ShopTier("Stun", player:GetAttribute("StunTier") or 1)
		player:SetAttribute("HasStunner", true)
		player:SetAttribute("StunCharges", math.max(player:GetAttribute("StunCharges") or 0, (D().StunCharges or 3) + (tier and tier.Bonus or 0)))
		player:SetAttribute("Flares", math.max(player:GetAttribute("Flares") or 0, 2))
		player:SetAttribute("Syringes", player:GetAttribute("Syringes") or 1)
		st.protectedUntil = os.clock() + 5
	elseif round.ride and not round.crashed then
		if root then
			root.Anchored = true
		end
		st.chokeStart = os.clock()
		ChokeRemote:FireClient(player, "start", true)
	end
end

function round.crash()
	if round.crashed then
		return
	end
	round.crashed = true
	for _, p in inGamePlayers() do
		CrashRemote:FireClient(p)
	end
	local id = round.id
	task.delay(4.5, function()
		if round.active and round.id == id and not round.ending then
			round.startBoss()
		end
	end)
end

local function spawnWreckItem(spot, kind)
	if not round.boss or round.ending then
		return
	end
	local isSyr = kind == "Syringe"
	local it = itemPart(isSyr and "Syringe" or "FlarePickup", isSyr and Vector3.new(0.35, 0.35, 1.5) or Vector3.new(0.45, 0.45, 1.5),
		isSyr and Color3.fromRGB(190, 140, 255) or Color3.fromRGB(255, 70, 40), CFrame.new(spot.Position) * CFrame.Angles(0, math.random() * 6, 0))
	prompt(it, "Take", isSyr and "Tranquilizer Syringe" or "Flare", 0.2).Triggered:Connect(function(player)
		if not roster[player] or not it.Parent then
			return
		end
		local attr = isSyr and "Syringes" or "Flares"
		local stun = player:GetAttribute("StunCharges") or 0
		local stunLow = isSyr and stun < (Config.BossStunCharges or 6)
		if (player:GetAttribute(attr) or 0) >= (isSyr and Config.MaxSyringes or 3) and not stunLow then
			Notify:FireClient(player, "You can't carry any more.")
			return
		end
		it:Destroy()
		player:SetAttribute(attr, math.min((player:GetAttribute(attr) or 0) + 1, isSyr and Config.MaxSyringes or 3))
		if isSyr then
			-- the red crates are tranquilizer kits: a syringe AND stun cartridges
			player:SetAttribute("StunCharges", math.min(stun + 2, Config.BossStunCharges or 6))
		end
		Notify:FireClient(player, isSyr and "Tranquilizer kit: +1 syringe, +2 stun shots. STUN B-00 [Q], then INJECT it." or "+1 Flare [G]", Color3.fromRGB(200, 160, 255))
		local id = round.id
		task.delay(Config.WreckRespawn, function()
			if round.id == id then
				spawnWreckItem(spot, kind)
			end
		end)
	end)
end

function round.startBoss()
	round.boss = true
	round.ride = false
	setPhase(6)
	ReplicatedStorage:SetAttribute("Alarm", false)
	round.respawnCF = crashSpawns[1] and crashSpawns[1].CFrame
	round.fuelReady = true
	puddle.Transparency = 0.15
	for i, p in inGamePlayers() do
		local sp = crashSpawns[(i - 1) % #crashSpawns + 1]
		local _, root = charParts(p)
		if root then
			root.CFrame = sp.CFrame + Vector3.new(0, 1, 0)
			root.Anchored = false
		end
		local st = roster[p]
		st.protectedUntil = os.clock() + 5
		local tier = Config.ShopTier("Stun", p:GetAttribute("StunTier") or 1)
		p:SetAttribute("HasStunner", true)
		p:SetAttribute("StunCharges", math.max(p:GetAttribute("StunCharges") or 0, (Config.BossStunCharges or 6) + (tier and tier.Bonus or 0)))
		p:SetAttribute("Flares", math.max(p:GetAttribute("Flares") or 0, 3))
		p:SetAttribute("Syringes", math.max(p:GetAttribute("Syringes") or 0, Config.BossSyringes or 2))
	end
	local sp = CollectionService:GetTagged("BossSpawn")[1]
	local b = spawnMonster("Behemoth", CFrame.new(sp.Position))
	b.boss = true
	b.idleUntil = os.clock() + 4
	b.cfg.Sense = 220 -- out here it always knows where you are
	b.cfg.Hearing = 220
	b.cfg.ChaseSpeed *= (Config.BossSpeed or 1)
	b.cfg.PatrolSpeed *= (Config.BossSpeed or 1)
	local maxHP = math.floor(Config.BossHP * ((Config.BossHPScale or {})[round.difficulty or "Normal"] or 1))
	round.bossMaxHP = maxHP
	b.hp = maxHP
	b.model:SetAttribute("MaxHP", maxHP)
	ReplicatedStorage:SetAttribute("BossMaxHP", maxHP)
	ReplicatedStorage:SetAttribute("BossHP", b.hp)
	round.bossM = b
	-- at the player's eye level, and it always wins over nearby crate prompts
	local injectAt = Instance.new("Attachment")
	injectAt.Name = "InjectPoint"
	injectAt.Position = Vector3.new(0, -b.hip + 3, 0)
	injectAt.Parent = b.root
	local pr = prompt(injectAt, "INJECT SYRINGE", "Stunned B-00", 0.5, 16)
	pr.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	pr.Enabled = false
	pr.Style = Enum.ProximityPromptStyle.Default
	round.bossPrompt = pr
	pr.Triggered:Connect(function(player)
		if not roster[player] or b.dead or os.clock() > (b.stunnedUntil or 0) then
			return
		end
		local n = player:GetAttribute("Syringes") or 0
		if n <= 0 then
			Notify:FireClient(player, "No syringes - grab one from the red crates in the wreck.")
			return
		end
		player:SetAttribute("Syringes", n - 1)
		round.hurtBoss(Config.SyringeDamage, player.DisplayName .. " jammed a syringe into it!", Color3.fromRGB(200, 160, 255), player)
	end)
	local wreck = CollectionService:GetTagged("WreckSpot")
	for i, w in wreck do
		spawnWreckItem(w, i % 2 == 1 and "Syringe" or "Flare")
	end
	notifyAll("THE VAN CRASHED - B-00 IS LOOSE. KILL IT!", Color3.fromRGB(255, 60, 50))
	setObjective("KILL B-00. Stun it [Q] then INJECT a syringe (red crates) - or throw a flare [G] into the fuel puddle while it's standing in it!")
	for _, p in inGamePlayers() do
		RoarRemote:FireClient(p, 1)
	end
end

function round.hurtBoss(amount, msg, color, who)
	local b = round.bossM
	if not b or b.dead or round.ending then
		return
	end
	if who then
		round.damage = round.damage or {}
		round.damage[who.DisplayName] = (round.damage[who.DisplayName] or 0) + math.min(amount, b.hp)
	end
	b.hp = math.max(0, b.hp - amount)
	ReplicatedStorage:SetAttribute("BossHP", b.hp)
	if b.growl then
		b.growl:Play()
	end
	notifyAll(msg .. ("   B-00: %d%%"):format(math.ceil(b.hp / (round.bossMaxHP or Config.BossHP) * 100)), color)
	if b.hp <= 0 then
		round.bossDies()
	elseif not b.enraged and b.hp <= (round.bossMaxHP or Config.BossHP) * 0.5 then
		b.enraged = true
		b.cfg.ChaseSpeed *= 1.1
		b.cfg.PatrolSpeed *= 1.1
		for _, p in inGamePlayers() do
			RoarRemote:FireClient(p, 1)
		end
		task.delay(1.5, function()
			notifyAll("B-00 IS ENRAGED - it's faster now!", Color3.fromRGB(255, 70, 50))
		end)
		-- on Hard / Nightmare it screams for help
		local extra = (Config.EnrageCrawlers or {})[round.difficulty or "Normal"] or 0
		local id = round.id
		for i = 1, extra do
			task.delay(3 + i * 1.5, function()
				if round.id ~= id or not round.boss or round.ending or b.dead then
					return
				end
				local pts = round.bossPoints
				local c = spawnMonster("Crawler", CFrame.new(pts[(i * 3) % #pts + 1]))
				c.arena = true
				c.idleUntil = os.clock() + 2
				if i == 1 then
					notifyAll("Its scream echoes through the trees... CRAWLERS are coming out of the woods!", Color3.fromRGB(255, 90, 80))
				end
			end)
		end
	end
end

function round.bossDies()
	local b = round.bossM
	b.dead = true
	b.captured = true
	b.charging = false
	b.model:SetAttribute("Chasing", nil)
	b.model:SetAttribute("Charging", nil)
	b.model:SetAttribute("Dead", true)
	ReplicatedStorage:SetAttribute("BossDeathPos", b.feetPos)
	ReplicatedStorage:SetAttribute("BossDeathYaw", b.yaw)
	if round.bossPrompt then
		round.bossPrompt:Destroy()
		round.bossPrompt = nil
	end
	for _, m in monsters do
		if m ~= b then
			m.captured = true
		end
	end
	task.spawn(function()
		local from = b.root.CFrame
		for i = 1, 40 do
			local k = math.sin(i / 40 * math.pi / 2)
			b.root.CFrame = from * CFrame.Angles(0, 0, math.rad(88) * k) - Vector3.new(0, b.hip * 0.55 * k, 0)
			task.wait(0.03)
		end
	end)
	notifyAll("B-00 IS DEAD.", Color3.fromRGB(120, 255, 140))
	setObjective("B-00 is dead.")
	task.delay(3.5, win)
end

function round.flareHit(pos, who, from)
	local b = round.bossM
	if not b or b.dead then
		return
	end
	local flat = function(v)
		return Vector3.new(v.X, 0, v.Z)
	end
	if round.fuelReady and (flat(pos) - flat(puddle.Position)).Magnitude <= puddleR + 2 then
		round.fuelReady = false
		puddle.Transparency = 1
		local ex = Instance.new("Explosion")
		ex.Position = puddle.Position + Vector3.new(0, 1, 0)
		ex.BlastRadius = 16
		ex.BlastPressure = 0
		ex.DestroyJointRadiusPercent = 0
		ex.Parent = workspace
		local burn = Instance.new("Part")
		burn.Anchored, burn.CanCollide, burn.CanQuery, burn.Transparency = true, false, false, 1
		burn.Size = Vector3.new(14, 1, 14)
		burn.Position = puddle.Position
		burn.Parent = workspace
		local f = Instance.new("Fire")
		f.Size, f.Heat = 25, 20
		f.Parent = burn
		local fl = Instance.new("PointLight")
		fl.Color, fl.Range, fl.Brightness = Color3.fromRGB(255, 150, 60), 50, 4
		fl.Parent = burn
		Debris:AddItem(burn, 6)
		for _, p in inGamePlayers() do
			RoarRemote:FireClient(p, 0.8)
		end
		if (flat(b.feetPos) - flat(puddle.Position)).Magnitude <= puddleR + 6 then
			b.stunnedUntil = os.clock() + 3
			round.hurtBoss(Config.FuelDamage, "KABOOM! The fuel went up right under it!", Color3.fromRGB(255, 160, 60), who)
		else
			notifyAll("The fuel went up... but B-00 wasn't standing in it!", Color3.fromRGB(255, 160, 90))
		end
		local id = round.id
		task.delay(Config.FuelRefill, function()
			if round.id == id and round.boss and not round.ending then
				round.fuelReady = true
				puddle.Transparency = 0.15
				notifyAll("Fuel is pooling under the van again...", Color3.fromRGB(200, 180, 140))
			end
		end)
	elseif (flat(pos) - flat(b.feetPos)).Magnitude <= 10 or (from and (function()
		-- did the flare fly through it on the way? (closest point on the throw to its body)
		local a, c = flat(from), flat(pos)
		local ab = c - a
		local t = ab.Magnitude > 0 and math.clamp((flat(b.feetPos) - a):Dot(ab) / ab:Dot(ab), 0, 1) or 0
		return (a + ab * t - flat(b.feetPos)).Magnitude <= 7
	end)()) then
		round.hurtBoss(Config.FlareDamage, "The flare burns it!", Color3.fromRGB(255, 140, 90), who)
	end
end
task.spawn(function()
	while true do
		task.wait(0.2)
		if round.active and not round.ending and round.boss and round.bossM and round.bossPrompt then
			round.bossPrompt.Enabled = not round.bossM.dead and os.clock() < (round.bossM.stunnedUntil or 0)
		end
		if round.active and not round.ending and not round.ride then
			-- flare distraction
			if activeFlare and os.clock() > activeFlare.untilT then
				activeFlare = nil
			end
			for _, p in inGamePlayers() do
				local _, root = charParts(p)
				if root and inBox(exitZone, root.Position) then
					if round.captured and round.called then
						round.startRide()
					elseif round.lastVanMsg ~= p or os.clock() - (round.lastVanMsgT or 0) > 4 then
						round.lastVanMsg, round.lastVanMsgT = p, os.clock()
						Notify:FireClient(p, round.captured and "Radio Wildcrest from the Security office first!" or "Not yet - capture the Behemoth first!")
					end
				end
			end
		end
	end
end)

-- Round setup ---------------------------------------------------------------------------------------
function resetRound()
	round.active = false
	round.ending = false
	round.choosing = false
	ReplicatedStorage:SetAttribute("DifficultyChoosing", false)
	clearMonsters()
	itemsFolder:ClearAllChildren()
	round.captured, round.baitPlaced, round.baitCarrier = false, false, nil
	round.trapped, round.sedative, round.baitLaced, round.called = false, false, false, false
	round.ride, round.crashed, round.boss, round.bossM, round.respawnCF, round.fuelReady = false, false, false, nil, nil, false
	round.damage = {}
	if round.bossPrompt then
		round.bossPrompt:Destroy()
		round.bossPrompt = nil
	end
	ReplicatedStorage:SetAttribute("BossHP", 0)
	table.clear(round.clamps)
	for _, c in clampModels do
		paintClamp(c, false)
	end
	round.setClampPrompts(false)
	setHandleFixed(false)
	radioLight.Color = Color3.fromRGB(255, 60, 40)
	radioPrompt.Enabled = true
	for _, a in { "SedativeFound", "BaitLaced", "PickupCalled" } do
		ReplicatedStorage:SetAttribute(a, false)
	end
	ReplicatedStorage:SetAttribute("ClampsLocked", 0)
	ReplicatedStorage:SetAttribute("BaitPlaced", false)
	fuseCount = 0
	ReplicatedStorage:SetAttribute("ZooFuses", 0)
	ReplicatedStorage:SetAttribute("RadarReadyAt", 0)
	setPhase(0)
	setObjective("")
	setPower(false)
	cageGate:PivotTo(gateHome)
	leverLight.Color = Color3.fromRGB(255, 60, 40)
	winchReadyAt = 0
	activeFlare = nil
	for _, p in Players:GetPlayers() do
		p:SetAttribute("HasStunner", nil)
		p:SetAttribute("StunCharges", nil)
		p:SetAttribute("CarryingMoney", false)
		p:SetAttribute("Flares", nil)
		p:SetAttribute("HasHandle", nil)
		p:SetAttribute("Syringes", nil)
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
		st.lives = d.Lives + (p:GetAttribute("Up_ExtraLife") or 0)
		p:SetAttribute("Lives", st.lives)
	end
	notifyAll((who and (who.DisplayName .. " chose ") or "Difficulty: ") .. string.upper(name) .. ". Good luck.", d.Color)
	setObjective("Capture the Behemoth. First, restore power: find " .. Config.FusesNeeded .. " fuses for the generator (Maintenance).")
	local sp = CollectionService:GetTagged("BehemothSpawn")[1]
	if sp then
		spawnMonster("Behemoth", CFrame.new(sp.Position)).idleUntil = os.clock() + 3
	end
	-- a few of the "little ones" already prowl the mall (the notes warn about them)
	local early = (Config.EarlyCrawlers or {})[name] or 0
	local cs = CollectionService:GetTagged("CrawlerSpawn")
	table.sort(cs, function(x, y) -- the pet store first
		return (x.Position - Vector3.new(-70, 0, -25)).Magnitude < (y.Position - Vector3.new(-70, 0, -25)).Magnitude
	end)
	for i = 1, math.min(early, #cs) do
		spawnMonster("Crawler", CFrame.new(cs[i].Position)).idleUntil = os.clock() + 6 + i * 2
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
	spawnFuses()
	spawnStunGun()
	round.spawnBait()
	round.spawnHandle()
	round.spawnSedative()
	for _, s in CollectionService:GetTagged("CartridgeSpot") do
		spawnCartridge(s)
	end
	for _, s in CollectionService:GetTagged("BatterySpot") do
		spawnBattery(s)
	end
	spawnCash()
	round.difficulty = nil
	round.choosing = true
	ReplicatedStorage:SetAttribute("Difficulty", "")
	ReplicatedStorage:SetAttribute("DifficultyChoosing", true)
	-- the intro cutscene plays first; the pick timer starts after it
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
	local lives = savedLives[player.UserId] or (D().Lives + (player:GetAttribute("Up_ExtraLife") or 0))
	savedLives[player.UserId] = nil
	roster[player] = { lives = lives, sprinting = false, moving = false, flashlight = false }
	player:SetAttribute("InGame", true)
	player:SetAttribute("Lives", lives)
	player:SetAttribute("Hidden", false)
	player:SetAttribute("CarryingMoney", false)
	player:SetAttribute("Flares", player:GetAttribute("Flares") or Config.FlaresPerRound)
	task.spawn(applyPasses, player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			removeFromRound(player, true)
		end)
	end
end

local function joinRound(player)
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
	if round.joinFinale then
		round.joinFinale(player) -- (joined or respawned during the ride / the fight)
	end
	task.delay((ReplicatedStorage:GetAttribute("IntroUntil") or 0) > workspace:GetServerTimeNow() and 1 or 0, function()
		if (ReplicatedStorage:GetAttribute("IntroUntil") or 0) <= workspace:GetServerTimeNow() then
			Notify:FireClient(player, "The van drops you at the mall. Something big is breathing inside.")
		end
	end)
end
local OUTFITS = {
	agent = { "http://www.roblox.com/asset/?id=14445685478", "http://www.roblox.com/asset/?id=8961661733" },
	director = { "http://www.roblox.com/asset/?id=11646123997", "http://www.roblox.com/asset/?id=16419869691" },
	guest = { "http://www.roblox.com/asset/?id=95561865974073", "http://www.roblox.com/asset/?id=71191835847953" },
}
local function readUpgrades(p)
	local up = {}
	pcall(function()
		local td = p:GetJoinData().TeleportData
		if type(td) == "table" and type(td.UpgradesByUser) == "table" and type(td.UpgradesByUser[tostring(p.UserId)]) == "table" then
			up = td.UpgradesByUser[tostring(p.UserId)]
		end
	end)
	p:SetAttribute("Up_ExtraLife", math.clamp(tonumber(up.extraLife) or 0, 0, 6))
	p:SetAttribute("Up_FlashSkin", type(up.flashSkin) == "string" and up.flashSkin:sub(1, 20) or "")
	p:SetAttribute("Up_Skin", type(up.skin) == "string" and up.skin:sub(1, 20) or "")
end
local function wearOutfit(p, char)
	local o = OUTFITS[p:GetAttribute("Up_Skin") or ""]
	if not o or not char then
		return
	end
	local sh = char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt", char)
	sh.ShirtTemplate = o[1]
	local pa = char:FindFirstChildOfClass("Pants") or Instance.new("Pants", char)
	pa.PantsTemplate = o[2]
end
local function onPlayer(p)
	readUpgrades(p)
	p.CharacterAdded:Connect(function(char)
		task.defer(wearOutfit, p, char)
		task.defer(function()
			if not roster[p] then
				joinRound(p)
			end
		end)
	end)
	if p.Character then
		task.defer(wearOutfit, p, p.Character)
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
	saveProfile(p)
	profiles[p] = nil
	loadedOk[p] = nil
	lastStun[p] = nil
	task.defer(function()
		if round.active and not round.ending and #inGamePlayers() == 0 then
			resetRound()
		end
	end)
end)

-- Studio-only test hook (never exists in a live server)
if RunService:IsStudio() then
	local dbg = Instance.new("BindableFunction")
	dbg.Name = "MallDebug"
	dbg.Parent = ServerStorage
	dbg.OnInvoke = function(cmd, arg)
		if cmd == "state" then
			local b = round.bossM
			return { phase = round.phase, captured = round.captured, called = round.called, ride = round.ride, crashed = round.crashed,
				boss = round.boss, hp = b and b.hp, bossPos = b and b.feetPos, stunned = b and os.clock() < (b.stunnedUntil or 0), monsters = #monsters }
		elseif cmd == "skipCapture" then
			setPower(true)
			setHandleFixed(true)
			round.captured, round.trapped, round.called = true, true, true
			clearMonsters()
			setPhase(4)
			ReplicatedStorage:SetAttribute("PickupCalled", true)
			return "ok"
		elseif cmd == "behemothTo" then
			local m = behemoth()
			if m then
				m.feetPos = arg
				m.waypoints = nil
				m.state = "Patrol"
				m.idleUntil = os.clock() + 999
			end
			return "ok"
		elseif cmd == "bossInfo" then
			local b = round.bossM
			if not b then
				return "no boss"
			end
			local wp = b.waypoints and b.waypoints[#b.waypoints]
			return ("state=%s feet=%s goal=%s lastSeen=%s stunned=%s"):format(tostring(b.state), tostring(b.feetPos), tostring(wp), tostring(b.lastSeenPos), tostring(os.clock() < (b.stunnedUntil or 0)))
		elseif cmd == "wake" then
			local m = behemoth()
			if m then
				m.idleUntil = 0
			end
			return "ok"
		elseif cmd == "power" then
			setPower(true)
			return "ok"
		elseif cmd == "hurt" then
			round.hurtBoss(arg or 10, "(test damage)")
			return round.bossM and round.bossM.hp
		elseif cmd == "ride" then
			round.startRide()
			return "ok"
		elseif cmd == "crash" then
			round.crash()
			return "ok"
		elseif cmd == "stunBoss" then
			if round.bossM then
				round.bossM.stunnedUntil = os.clock() + (arg or 6)
			end
			return "ok"
		elseif cmd == "bossTo" then
			if round.bossM then
				round.bossM.feetPos = arg
				round.bossM.waypoints = nil
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
		if round.boss then
			player:SetAttribute("Syringes", Config.MaxSyringes or 2)
		end
		say("Refilled: stun gun, flares" .. (round.boss and ", syringes." or "."))
	elseif cmd == "cash" then
		addCash(player, 1000)
		say("+$1000")
	elseif cmd == "clear" then
		if round.boss then
			say("Not during the boss fight - use HURT B-00 or WIN instead.")
			return
		end
		clearMonsters()
		say("Monsters removed.")
	elseif cmd == "power" then
		setPower(true)
		say("Power ON.")
	elseif cmd == "skipCapture" then
		if round.phase >= 4 then
			say("B-00 is already captured.")
			return
		end
		setPower(true)
		setHandleFixed(true)
		round.captured, round.trapped, round.called = true, true, true
		clearMonsters()
		setPhase(4)
		ReplicatedStorage:SetAttribute("PickupCalled", true)
		setObjective("Get back to the van in the parking lot - the cage gets loaded in the back.")
		say("Capture skipped - get to the van.")
	elseif cmd == "boss" then
		if round.boss then
			say("Already in the boss fight.")
			return
		end
		if round.phase < 4 then
			setPower(true)
			setHandleFixed(true)
			round.captured, round.trapped, round.called = true, true, true
			clearMonsters()
			setPhase(4)
		end
		round.crash()
		say("Skipping to the crash...")
	elseif cmd == "hurt" then
		if not round.boss or not round.bossM then
			say("Only in the boss fight.")
			return
		end
		round.hurtBoss(25, player.DisplayName .. " (admin) hurt B-00!", Color3.fromRGB(255, 220, 90), player)
	elseif cmd == "win" then
		if round.boss and round.bossM and not round.bossM.dead then
			round.hurtBoss(round.bossM.hp, "B-00 was finished off.", Color3.fromRGB(255, 220, 90), player)
		elseif not round.ending then
			win()
		end
	end
end)
resetRound()
