local B = {}
B.H = 14 -- floor height
function B.part(parent, name, size, cf, color, mat, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color or Color3.fromRGB(150, 150, 150)
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if props then for k, v in props do p[k] = v end end
	p.Parent = parent
	return p
end
-- box from min/max corners
function B.box(parent, name, a, b, color, mat, props)
	local mn = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local mx = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	return B.part(parent, name, mx - mn, CFrame.new((mn + mx) / 2), color, mat, props)
end
-- straight wall along X or Z from p0 to p1 (floor level y0), height h, thickness t, with door/window holes
-- holes = { {from, to, bottom, top}, ... } measured along the wall from p0
function B.wall(parent, name, p0, p1, y0, h, t, color, mat, holes)
	local dir = (p1 - p0)
	local len = dir.Magnitude
	local u = dir.Unit
	local cuts = {}
	for _, hl in holes or {} do table.insert(cuts, hl) end
	table.sort(cuts, function(x, y) return x[1] < y[1] end)
	local function seg(a, b, ya, yb)
		if b - a < 0.05 or yb - ya < 0.05 then return end
		local mid = p0 + u * ((a + b) / 2)
		local cf = CFrame.lookAt(Vector3.new(mid.X, y0 + (ya + yb) / 2, mid.Z), Vector3.new(mid.X, y0 + (ya + yb) / 2, mid.Z) + u)
		B.part(parent, name, Vector3.new(t, yb - ya, b - a), cf, color, mat)
	end
	local x = 0
	for _, c in cuts do
		seg(x, c[1], 0, h)
		seg(c[1], c[2], 0, c[3])
		seg(c[1], c[2], c[4], h)
		x = c[2]
	end
	seg(x, len, 0, h)
end
function B.light(part, kind, props)
	local l = Instance.new(kind or "PointLight")
	for k, v in props or {} do l[k] = v end
	l.Parent = part
	return l
end
function B.folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new("Folder") f.Name = name f.Parent = parent end
	return f
end
function B.model(parent, name)
	local f = Instance.new("Model") f.Name = name f.Parent = parent
	return f
end
return B
