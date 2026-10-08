
-- ---------------------------------------------------------------- lights & fx
local FACEFOR = { ["+z"] = NID.Back, ["-z"] = NID.Front, ["+x"] = NID.Right, ["-x"] = NID.Left }

local function addLight(kind, parent, color, bright, range, o)
	o = o or {}
	if CFG.LIGHT_DENSITY < 1 and not o.keep and rng:NextNumber() > CFG.LIGHT_DENSITY then return nil end
	local L
	if kind == "point" then
		L = Instance.new("PointLight")
	elseif kind == "spot" then
		L = Instance.new("SpotLight")
		L.Angle = o.angle or 90
		L.Face = o.face or NID.Bottom
	else
		L = Instance.new("SurfaceLight")
		L.Angle = o.angle or 150
		L.Face = o.face or NID.Bottom
	end
	L.Color = color
	L.Brightness = bright * CFG.LIGHT_SCALE
	L.Range = range
	L.Shadows = o.shadows == true
	L.Parent = parent
	return L
end

-- ceiling strip light (fluorescent). o: dead, flicker(0..1), shadows, angle
local function lampStrip(r, cx, y, cz, axis, len, color, bright, range, o)
	o = o or {}
	local sx, sz = len, 1.1
	if axis == "z" then sx, sz = 1.1, len end
	cb(r.lights, "LampHousing", cx, y - 0.12, cz, sx, 0.24, sz, 0, M.Metal, PAL.steelDark, { deco = true })
	local lit = not o.dead
	local tube = cb(r.lights, "LampTube", cx, y - 0.27, cz, sx - 0.3, 0.1, sz - 0.3, 0,
		lit and M.Neon or M.SmoothPlastic, lit and color or shade(color, 0.22), { deco = true })
	if lit then addLight("surface", tube, color, bright, range, { shadows = o.shadows, angle = o.angle }) end
	if o.flicker and lit then
		tag(tube, "FlickerLight")
		tube:SetAttribute("Flicker", o.flicker)
	end
	return tube
end

-- caged industrial lamp (maintenance / storage / bunker look)
local function lampCage(r, cx, y, cz, color, bright, range, o)
	o = o or {}
	cb(r.lights, "CageMount", cx, y - 0.15, cz, 1.2, 0.3, 3.4, 0, M.Metal, PAL.steelDark, { deco = true })
	local lit = not o.dead
	local tube = cb(r.lights, "CageTube", cx, y - 0.5, cz, 0.7, 0.35, 3.0, 0,
		lit and M.Neon or M.SmoothPlastic, lit and color or shade(color, 0.2), { deco = true })
	for _, dx in ipairs({ -0.55, 0.55 }) do
		cb(r.lights, "CageBar", cx + dx, y - 0.5, cz, 0.12, 0.6, 3.3, 0, M.Metal, PAL.steelDark, { deco = true })
	end
	if lit then addLight("point", tube, color, bright, range, { shadows = o.shadows }) end
	if o.flicker and lit then
		tag(tube, "FlickerLight")
		tube:SetAttribute("Flicker", o.flicker)
	end
	return tube
end

-- small wall sconce / status light (facing = direction it points)
local function lampWall(r, x, y, z, facing, color, bright, range, o)
	o = o or {}
	local yaw = yawOf(facing)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	mk(r.lights, "SconceBase", Vector3.new(1.4, 0.8, 0.3), cf * CFrame.new(0, 0, 0.15), M.Metal, PAL.steelDark, { deco = true })
	local g = mk(r.lights, "SconceGlass", Vector3.new(1.0, 0.5, 0.2), cf * CFrame.new(0, 0, 0.38), M.Neon, color, { deco = true })
	if not o.noLight then addLight("point", g, color, bright, range, { shadows = false }) end
	if o.flicker then
		tag(g, "FlickerLight")
		g:SetAttribute("Flicker", o.flicker)
	end
	return g
end

-- red emergency beacon, pulses via client script
local function lampRed(r, x, y, z, facing, o)
	o = o or {}
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yawOf(facing), 0)
	mk(r.lights, "BeaconBase", Vector3.new(1.4, 1.4, 0.4), cf * CFrame.new(0, 0, 0.2), M.Metal, PAL.steelDark, { deco = true })
	local dome = mk(r.lights, "BeaconDome", Vector3.new(1.1, 1.1, 0.9), cf * CFrame.new(0, 0, 0.7), M.Neon, C(230, 30, 24), { deco = true, shape = Enum.PartType.Ball })
	addLight("point", dome, C(255, 40, 30), o.bright or 2.2, o.range or 22, { shadows = false, keep = true })
	tag(dome, "PulseLight")
	dome:SetAttribute("Speed", o.speed or 2.2)
	return dome
end

-- invisible light carrier (chest glow, accent washes)
local function glow(r, x, y, z, color, bright, range, kind)
	local p = mk(r.lights, "Glow", Vector3.new(0.4, 0.4, 0.4), CFrame.new(x, y, z), M.SmoothPlastic, PAL.black, { deco = true, tr = 1 })
	addLight(kind or "point", p, color, bright, range, { shadows = false, keep = true })
	return p
end

-- particle emitters --------------------------------------------------------
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local function emitter(r, x, y, z, kind, o)
	o = o or {}
	local sz = o.size or Vector3.new(0.5, 0.5, 0.5)
	local p = mk(r.props, "FX_" .. kind, sz, CFrame.new(x, y, z), M.SmoothPlastic, PAL.black, { deco = true, tr = 1 })
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0.6
	if kind == "steam" then
		e.Texture = SMOKE
		e.Rate = o.rate or 7
		e.Lifetime = NumberRange.new(2.5, 4)
		e.Speed = NumberRange.new(o.speed or 4, (o.speed or 4) + 3)
		e.SpreadAngle = Vector2.new(14, 14)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 4.5) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.6, 0.86), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(C(205, 208, 206))
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.EmissionDirection = o.dir or NID.Top
	elseif kind == "dust" then
		e.Texture = SMOKE
		e.Rate = o.rate or 3
		e.Lifetime = NumberRange.new(7, 11)
		e.Speed = NumberRange.new(0.1, 0.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.9) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.9), NumberSequenceKeypoint.new(0.8, 0.9), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(C(190, 185, 170))
		e.Shape = Enum.ParticleEmitterShape.Box
	elseif kind == "spark" then
		e.Texture = SPARK
		e.Rate = 0
		e.Lifetime = NumberRange.new(0.3, 0.7)
		e.Speed = NumberRange.new(8, 18)
		e.SpreadAngle = Vector2.new(55, 55)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
		e.Color = ColorSequence.new(C(255, 190, 90))
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Acceleration = Vector3.new(0, -40, 0)
		e.EmissionDirection = o.dir or NID.Bottom
		tag(p, "SparkSource")
		p:SetAttribute("Every", o.every or 6)
	elseif kind == "drip" then
		e.Texture = SPARK
		e.Rate = o.rate or 1.4
		e.Lifetime = NumberRange.new(0.8, 1.1)
		e.Speed = NumberRange.new(0, 0)
		e.SpreadAngle = Vector2.new(0, 0)
		e.Size = NumberSequence.new(0.18)
		e.Transparency = NumberSequence.new(0.35)
		e.Color = ColorSequence.new(C(150, 180, 190))
		e.Acceleration = Vector3.new(0, -34, 0)
		e.EmissionDirection = NID.Bottom
	end
	e.Parent = p
	return p
end

-- ---------------------------------------------------------------- text / signs
local function surfText(part, face, text, fg, o)
	o = o or {}
	local s = part.Size
	local w, h
	if face == NID.Front or face == NID.Back then
		w, h = s.X, s.Y
	elseif face == NID.Left or face == NID.Right then
		w, h = s.Z, s.Y
	else
		w, h = s.X, s.Z
	end
	local ppu = o.ppu or 44
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(math.max(16, math.floor(w * ppu)), math.max(16, math.floor(h * ppu)))
	g.LightInfluence = o.glow and 0 or 1
	g.Parent = part
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = g
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = holder
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextColor3 = fg
	t.Font = o.font or Enum.Font.GothamBold
	t.TextScaled = true
	t.TextWrapped = true
	t.Parent = holder
	return g
end

local function hazardGradient(parent, c0, c1)
	local n = 10
	local kps = {}
	kps[#kps + 1] = ColorSequenceKeypoint.new(0, c0)
	for i = 1, n - 1 do
		local before = (i - 1) % 2 == 0 and c0 or c1
		local after = i % 2 == 0 and c0 or c1
		kps[#kps + 1] = ColorSequenceKeypoint.new(i / n - 0.0005, before)
		kps[#kps + 1] = ColorSequenceKeypoint.new(i / n + 0.0005, after)
	end
	kps[#kps + 1] = ColorSequenceKeypoint.new(1, (n - 1) % 2 == 0 and c0 or c1)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	local gr = Instance.new("UIGradient")
	gr.Color = ColorSequence.new(kps)
	gr.Rotation = 45
	gr.Parent = f
	f.Parent = parent
end

-- diagonal yellow/black hazard stripes on a part face
local function hazardFace(part, face, c0, c1)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(256, 64)
	g.Parent = part
	hazardGradient(g, c0 or PAL.yellow, c1 or PAL.black)
end
