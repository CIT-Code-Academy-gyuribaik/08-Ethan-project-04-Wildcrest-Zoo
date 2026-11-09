local P = {}
local function isFree(cf, size, ignore)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	for _, p in workspace:GetPartBoundsInBox(cf, size, params) do
		if p.CanCollide and p.Transparency < 1 then
			return false
		end
	end
	return true
end
function P.build(parent, name, floorPos, facing, color)
	local m = Instance.new("Model")
	m.Name = name
	local cf = CFrame.lookAt(floorPos + Vector3.new(0, 4, 0), floorPos + Vector3.new(0, 4, 0) + facing)
	local function part(n, size, offset)
		local p = Instance.new("Part")
		p.Name = n
		p.Anchored = true
		p.Size = size
		p.CFrame = cf * offset
		p.Color = color or Color3.fromRGB(85, 95, 100)
		p.Material = Enum.Material.Metal
		p.Parent = m
		return p
	end
	part("Body", Vector3.new(3, 8, 0.25), CFrame.new(0, 0, 1.4))
	part("Body", Vector3.new(0.25, 8, 3), CFrame.new(-1.4, 0, 0))
	part("Body", Vector3.new(0.25, 8, 3), CFrame.new(1.4, 0, 0))
	part("Body", Vector3.new(3, 0.25, 3), CFrame.new(0, 3.9, 0))
	local door = part("Door", Vector3.new(2.8, 7.6, 0.2), CFrame.new(0, -0.1, -1.45))
	door.Color = (color or Color3.fromRGB(85, 95, 100)):Lerp(Color3.new(1, 1, 1), 0.08)
	for k = -1, 1 do
		local v = part("Vent", Vector3.new(1.4, 0.15, 0.05), CFrame.new(0, 2.6 + k * 0.4, -1.57))
		v.Color = Color3.fromRGB(30, 30, 30)
		v.CanCollide = false
	end
	local inside = part("Inside", Vector3.new(1, 1, 1), CFrame.new(0, -1, 0))
	inside.Transparency, inside.CanCollide, inside.CanQuery = 1, false, false
	m.Parent = parent
	return m
end
function P.place(parent, candidates, maxCount, prefix, color)
	local made = {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, n in { "Monsters", "Items" } do
		if workspace:FindFirstChild(n) then table.insert(ignore, workspace[n]) end
	end
	params.FilterDescendantsInstances = ignore
	-- anything with a prompt (doors, stations, items) must stay reachable
	local busy = {}
	for _, pr in workspace:GetDescendants() do
		if pr:IsA("ProximityPrompt") and pr.Parent:IsA("BasePart") then table.insert(busy, pr.Parent.Position) end
	end
	for _, pt in candidates do
		if #made >= maxCount then break end
		local down = workspace:Raycast(pt + Vector3.new(0, 3, 0), Vector3.new(0, -8, 0), params)
		if down then
			local floor = down.Position
			local best
			for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
				local h = workspace:Raycast(floor + Vector3.new(0, 4, 0), d * 6, params)
				if h and (not best or h.Distance < best.dist) then
					best = { dir = d, dist = h.Distance, pos = h.Position }
				end
			end
			if best then
				local center = Vector3.new(best.pos.X, floor.Y, best.pos.Z) - best.dir * 1.7
				local facing = -best.dir
				local cf = CFrame.new(center + Vector3.new(0, 4.1, 0))
				local front = workspace:Raycast(center + Vector3.new(0, 3, 0), facing * 7, params)
				local tooClose = false
				for _, o in made do
					if (o - center).Magnitude < 16 then tooClose = true end
				end
				for _, hs in parent:GetChildren() do
					local d = hs:FindFirstChild("Door")
					if d and (d.Position - center).Magnitude < 10 then tooClose = true end
				end
				for _, b in busy do
					if (Vector3.new(b.X, center.Y, b.Z) - center).Magnitude < 7 and math.abs(b.Y - center.Y) < 9 then tooClose = true end
				end
				-- not in a doorway: both sides of the locker must not be open-air gaps in the wall
				if not tooClose and not front and isFree(cf, Vector3.new(3.2, 7.6, 3.2), ignore) then
					P.build(parent, prefix .. (#made + 1), center, facing, color)
					table.insert(made, center)
				end
			end
		end
	end
	return #made
end
return P
