
-- =============================================================================
--  GAMEPLAY MARKERS  (tagged placeholders you wire to your own systems)
--    Tags:  PlayerSpawn  ChestSpawn  Extraction  EnemySpawn  NPCSpawn  PatrolPoint
--    Chest models carry Attributes  Tier ("Common"|"Uncommon"|"Rare"|"Legendary")  ChestId
-- =============================================================================
local MARK = fold(root, "GameplayMarkers")
local MK = {
	spawns = fold(MARK, "PlayerSpawns"), chests = fold(MARK, "Chests"), extraction = fold(MARK, "Extraction"),
	enemies = fold(MARK, "EnemySpawns"), npcs = fold(MARK, "NPCSpawns"), patrol = fold(MARK, "PatrolRoutes"),
	ambient = fold(MARK, "AmbientZones"),
}
local TIER = {
	Common = { mat = M.WoodPlanks, color = C(112, 84, 54), trim = PAL.steelDark, glow = nil },
	Uncommon = { mat = M.Metal, color = C(62, 96, 70), trim = PAL.steelLight, glow = PAL.green },
	Rare = { mat = M.Metal, color = C(50, 78, 120), trim = PAL.cyan, glow = PAL.cyan },
	Legendary = { mat = M.Metal, color = C(36, 32, 30), trim = C(255, 190, 70), glow = C(255, 190, 70) },
}
local chestCount = 0
local function chest(room, id, x, y0, z, facing, tier)
	local t = TIER[tier]
	chestCount += 1
	local m = Instance.new("Model")
	m.Name = id
	local cf = frame(x, y0, z, facing)
	local body = lp(m, "Body", cf, 0, 0.9, 0, 3.2, 1.8, 2.2, t.mat, t.color)
	lp(m, "Lid", cf, 0, 2.15, 0, 3.3, 0.7, 2.3, t.mat, shade(t.color, 1.12))
	lp(m, "LidTop", cf, 0, 2.62, 0, 3.0, 0.3, 2.0, t.mat, shade(t.color, 1.05), DECO)
	for _, ox in ipairs({ -1.1, 1.1 }) do
		lp(m, "Band", cf, ox, 1.3, 0, 0.3, 2.4, 2.35, M.Metal, t.trim == PAL.cyan and PAL.steelDark or t.trim, DECO)
	end
	local latch = lp(m, "Latch", cf, 0, 1.9, 1.15, 0.6, 0.8, 0.2, t.glow and M.Neon or M.Metal, t.glow or PAL.steelLight, DECO)
	m.PrimaryPart = body
	m:SetAttribute("Tier", tier)
	m:SetAttribute("ChestId", id)
	m.Parent = MK.chests
	tag(m, "ChestSpawn")
	-- a subtle practical light so the chest reads without an arrow
	if t.glow then
		glow(room, x, y0 + 3.2, z, t.glow, tier == "Legendary" and 1.4 or 0.8, tier == "Legendary" and 16 or 11)
	else
		glow(room, x, y0 + 3.2, z, C(255, 214, 160), 0.35, 9)
	end
	return m
end

local function marker(folder, name, x, y, z, t, attrs, size)
	local p = mk(folder, name, size or Vector3.new(3, 1, 3), CFrame.new(x, y, z), M.SmoothPlastic, PAL.cyan, { deco = true, tr = 1 })
	for k, v in pairs(attrs or {}) do p:SetAttribute(k, v) end
	tag(p, t)
	return p
end

-- player spawns (reception, facing the facility)
for i, x in ipairs({ -7, -2.5, 2.5, 7 }) do
	local s = Instance.new("SpawnLocation")
	s.Name = "Spawn" .. i
	s.Anchored = true
	s.CanCollide = false
	s.CanTouch = false
	s.Neutral = true
	s.Duration = 0
	s.Size = Vector3.new(4, 0.4, 4)
	s.CFrame = CFrame.new(x, 0.25, 29.5)
	s.Transparency = 1
	local d = s:FindFirstChildOfClass("Decal")
	if d then d:Destroy() end
	s.Parent = MK.spawns
	tag(s, "PlayerSpawn")
end

-- chests: integrated into their rooms
chest(ROOMS.Reception, "Chest_Reception_Desk", -10.2, 0, 4.6, "+z", "Common")
chest(ROOMS.Security, "Chest_Security_Armoury", -10, 0, -16.6, "+x", "Uncommon")
chest(ROOMS.ResearchLab, "Chest_Lab_BehindCell", -37, 0, -51.7, "+z", "Rare")
chest(ROOMS.Medical, "Chest_Medical_Treatment", 9.2, 0, -51.4, "+x", "Uncommon")
chest(ROOMS.StorageB, "Chest_Storage_Freight", -12.6, 0, -78.4, "-z", "Common")
chest(ROOMS.StorageB, "Chest_Storage_ShelfAisle", -31, 0, -80.8, "+z", "Common")
chest(ROOMS.Maintenance, "Chest_Power_Generator", 24.6, 0, -80.8, "+z", "Uncommon")
chest(ROOMS.Maintenance, "Chest_Power_UnderCatwalk", 43, 0, -80.4, "-x", "Common")
chest(ROOMS.ServiceHallA, "Chest_Service_DeadEnd", 35.4, 0, -107.8, "-z", "Rare")
chest(ROOMS.Containment, "Chest_Containment_Gallery", -17.5, 7, -132.6, "+z", "Legendary")

-- extraction zone: stand on the pad in front of the lift
marker(MK.extraction, "ExtractionZone", 0, 3.5, -148, "Extraction", { Name = "Evacuation Lift" }, Vector3.new(10, 7, 10))

-- enemy spawns (Type is yours to interpret)
for _, e in ipairs({
	{ -9, -131, "Elite", "Containment" }, { 14, -129, "Standard", "Containment" }, { 12, -101, "Standard", "Containment" },
	{ -20, -66, "Standard", "StorageB" }, { -41, -79, "Standard", "StorageB" }, { 36, -62, "Standard", "Maintenance" },
	{ -12, -37, "Standard", "ResearchLab" }, { 38, -38, "Standard", "Medical" }, { 34, -96, "Standard", "ServiceHall" },
	{ 0, -66, "Standard", "MainCorridor" },
}) do
	marker(MK.enemies, "EnemySpawn_" .. e[4], e[1], 0.5, e[2], "EnemySpawn", { Type = e[3], Zone = e[4] })
end
-- friendly NPC spawns
for _, e in ipairs({ { -14, 22, "Reception" }, { 16, 14, "Reception" }, { 4, -17, "Security" } }) do
	marker(MK.npcs, "NPCSpawn_" .. e[3], e[1], 0.5, e[2], "NPCSpawn", { Zone = e[3] })
end
-- patrol routes: ordered points, Attribute Route + Index
local ROUTES = {
	MainSpine = { { 0, -28 }, { 0, -45 }, { 0, -62 }, { 0, -80 }, { 0, -62 }, { 0, -45 } },
	LabLoop = { { -10, -39 }, { -22, -39 }, { -30, -29 }, { -22, -50 }, { -12, -45 } },
	WardLoop = { { 12, -39 }, { 26, -39 }, { 40, -39 }, { 40, -33 }, { 26, -33 }, { 26, -44 } },
	StorageLoop = { { -11, -72 }, { -20, -66 }, { -31, -70 }, { -31, -62 }, { -26, -58 }, { -14, -62 } },
	PowerLoop = { { 11, -72 }, { 20, -58 }, { 32, -58 }, { 36, -72 }, { 28, -80 }, { 14, -66 } },
	ContainmentLoop = { { 0, -100 }, { 12, -108 }, { 13, -126 }, { 0, -132 }, { -10, -126 }, { -10, -108 } },
}
for rname, pts in pairs(ROUTES) do
	for i, p in ipairs(pts) do
		marker(MK.patrol, "Patrol_" .. rname .. "_" .. i, p[1], 0.5, p[2], "PatrolPoint", { Route = rname, Index = i }, Vector3.new(1.5, 1, 1.5))
	end
end
-- ambient sound zones (set the SoundId attribute to your own audio asset)
for _, z in ipairs({
	{ "Reception", 0, 18, 50, 36, "ventilation hum" }, { "ResearchLab", -26, -39, 40, 30, "electrical buzz" },
	{ "Maintenance", 26, -69, 40, 30, "machinery rumble" }, { "Containment", 0, -116, 44, 40, "low drone + alarm" },
	{ "StorageB", -26, -69, 40, 30, "distant metal creaks" }, { "Medical", 26, -39, 40, 30, "monitor beeps" },
}) do
	local p = marker(MK.ambient, "Ambient_" .. z[1], z[2], 6, z[3], "AmbientZone",
		{ SoundId = "", Volume = 0.5, Suggestion = z[6] }, Vector3.new(z[4], 12, z[5]))
	p.CanQuery = false
end

-- =============================================================================
--  FACILITY MAPS  (schematic wall maps: facing +z = viewer looks north, -z = looks south)
-- =============================================================================
local MAP_COL = {
	Reception = C(70, 110, 150), Security = C(150, 70, 70), MainCorridor = C(110, 112, 108), ResearchLab = C(70, 150, 170),
	Medical = C(90, 160, 120), StorageB = C(150, 130, 70), Maintenance = C(170, 110, 50), ServiceHallA = C(120, 90, 60),
	ServiceHallB = C(120, 90, 60), Decon = C(160, 160, 60), Containment = C(190, 50, 50), Extraction = C(60, 190, 100),
}
local function facilityMap(r, x, y, z, facing, w, h, here)
	local p = P.sign(r, "", x, y, z, w, h, facing, C(14, 22, 30), PAL.offwhite)
	for _, c in ipairs(p:GetChildren()) do c:Destroy() end
	local g = Instance.new("SurfaceGui")
	g.Face = NID.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(math.floor(w * 60), math.floor(h * 60))
	g.Parent = p
	local X0, X1, Z0, Z1 = -50, 50, -164, 40
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.08)
	title.Text = "SITE 9  -  FACILITY MAP"
	title.TextColor3 = PAL.offwhite
	title.Font = Enum.Font.Code
	title.TextScaled = true
	title.Parent = g
	local box = Instance.new("Frame")
	box.Position = UDim2.fromScale(0.04, 0.1)
	box.Size = UDim2.fromScale(0.92, 0.86)
	box.BackgroundTransparency = 1
	box.Parent = g
	for name, rm in pairs(ROOMS) do
		local x0, x1, z0, z1 = rm.x0, rm.x1, rm.z0, rm.z1
		local sx0, sx1, sy0, sy1
		if facing == "+z" then
			sx0, sx1 = (x0 - X0) / (X1 - X0), (x1 - X0) / (X1 - X0)
			sy0, sy1 = (z0 - Z0) / (Z1 - Z0), (z1 - Z0) / (Z1 - Z0)
		else
			sx0, sx1 = (X1 - x1) / (X1 - X0), (X1 - x0) / (X1 - X0)
			sy0, sy1 = (Z1 - z1) / (Z1 - Z0), (Z1 - z0) / (Z1 - Z0)
		end
		local f = Instance.new("Frame")
		f.Position = UDim2.fromScale(sx0, sy0)
		f.Size = UDim2.fromScale(sx1 - sx0, sy1 - sy0)
		f.BackgroundColor3 = MAP_COL[name] or PAL.steel
		f.BorderSizePixel = 1
		f.BackgroundTransparency = (name == here) and 0 or 0.45
		f.Parent = box
		if name == here then
			local d = Instance.new("TextLabel")
			d.BackgroundTransparency = 1
			d.Size = UDim2.fromScale(1, 1)
			d.Text = "YOU ARE HERE"
			d.TextColor3 = C(255, 255, 255)
			d.Font = Enum.Font.GothamBlack
			d.TextScaled = true
			d.Parent = f
		end
	end
	return p
end
facilityMap(ROOMS.Reception, 17, 8.4, 1.0, "+z", 6, 8.6, "Reception")
facilityMap(ROOMS.Security, 10, 7.4, -1.0, "-z", 5, 6.8, "Security")

-- =============================================================================
--  ATMOSPHERE  (global lighting, post effects, client ambience script)
-- =============================================================================
pcall(function() Lighting.Technology = Enum.Technology.Future end)
Lighting.Brightness = 0
Lighting.ClockTime = 0
Lighting.Ambient = C(15, 17, 21)
Lighting.OutdoorAmbient = C(0, 0, 0)
Lighting.ExposureCompensation = 0.35
Lighting.GlobalShadows = true
pcall(function() Lighting.EnvironmentDiffuseScale = 0.06 end)
pcall(function() Lighting.EnvironmentSpecularScale = 0.35 end)
pcall(function() Lighting.ShadowSoftness = 0.25 end)
local atm = Instance.new("Atmosphere")
atm.Name = "FacilityFX_Atmosphere"
atm.Density = 0.3
atm.Offset = 0
atm.Color = C(34, 38, 44)
atm.Decay = C(14, 16, 20)
atm.Glare = 0
atm.Haze = 0.6
atm.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "FacilityFX_Color"
cc.Brightness = 0.02
cc.Contrast = 0.2
cc.Saturation = -0.18
cc.TintColor = C(236, 242, 250)
cc.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Name = "FacilityFX_Bloom"
bloom.Intensity = 0.45
bloom.Size = 24
bloom.Threshold = 0.95
bloom.Parent = Lighting

local RUNTIME = [==[
-- FacilityAmbience (LocalScript): light flicker, pulsing beacons, fans, sparks, ambient audio zones.
local CS = game:GetService("CollectionService")
local RS = game:GetService("RunService")
local rng = Random.new()

local flick, pulse = {}, {}
local function lightOf(inst) return inst:FindFirstChildWhichIsA("Light") end
local function addFlick(inst)
	if not inst:IsA("BasePart") then return end
	local l = lightOf(inst)
	flick[inst] = { l = l, base = l and l.Brightness or 0, sev = inst:GetAttribute("Flicker") or 0.5,
		t = rng:NextNumber(0, 2), on = true, mat = inst.Material, col = inst.Color }
end
local function addPulse(inst)
	if not inst:IsA("BasePart") then return end
	local l = lightOf(inst)
	if l then pulse[inst] = { l = l, base = l.Brightness, speed = inst:GetAttribute("Speed") or 1.5, ph = rng:NextNumber(0, 6) } end
end
for _, i in ipairs(CS:GetTagged("FlickerLight")) do addFlick(i) end
for _, i in ipairs(CS:GetTagged("PulseLight")) do addPulse(i) end
CS:GetInstanceAddedSignal("FlickerLight"):Connect(addFlick)
CS:GetInstanceAddedSignal("PulseLight"):Connect(addPulse)

local fans = {}
for _, m in ipairs(CS:GetTagged("Fan")) do fans[m] = m:GetAttribute("Speed") or 3 end

local sparks, nextSpark = {}, {}
for _, p in ipairs(CS:GetTagged("SparkSource")) do
	sparks[p] = p:FindFirstChildOfClass("ParticleEmitter")
	nextSpark[p] = os.clock() + rng:NextNumber(1, p:GetAttribute("Every") or 6)
end

local t = 0
RS.Heartbeat:Connect(function(dt)
	t += dt
	for inst, s in pairs(flick) do
		s.t -= dt
		if s.t <= 0 then
			if s.on then
				if rng:NextNumber() < s.sev * 0.5 then
					s.on = false
					s.t = rng:NextNumber(0.03, 0.2)
				else
					s.t = rng:NextNumber(0.4, 3.5) / (0.4 + s.sev)
				end
			else
				s.on = true
				s.t = rng:NextNumber(0.1, 2.2) / (0.4 + s.sev)
			end
			if s.l then s.l.Brightness = s.on and s.base or s.base * rng:NextNumber(0, 0.12) end
			inst.Material = s.on and s.mat or Enum.Material.SmoothPlastic
		end
	end
	for _, s in pairs(pulse) do
		s.l.Brightness = s.base * (0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * s.speed + s.ph)))
	end
	for m, sp in pairs(fans) do
		if m.Parent then m:PivotTo(m:GetPivot() * CFrame.Angles(0, 0, sp * dt)) end
	end
	local now = os.clock()
	for p, e in pairs(sparks) do
		if e and now >= nextSpark[p] then
			e:Emit(rng:NextInteger(6, 14))
			nextSpark[p] = now + rng:NextNumber(1.5, p:GetAttribute("Every") or 6)
		end
	end
end)

-- ambient loops: set the SoundId attribute on parts in Workspace.Facility.GameplayMarkers.AmbientZones
for _, z in ipairs(CS:GetTagged("AmbientZone")) do
	local id = z:GetAttribute("SoundId")
	if id and id ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Looped = true
		s.Volume = z:GetAttribute("Volume") or 0.5
		s.RollOffMaxDistance = math.max(z.Size.X, z.Size.Z)
		s.Parent = z
		s:Play()
	end
end
]==]
if CFG.FLICKER then
	local sps = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	if sps then
		local old = sps:FindFirstChild("FacilityAmbience")
		if old then old:Destroy() end
		local ls = Instance.new("LocalScript")
		ls.Name = "FacilityAmbience"
		ls.Source = RUNTIME
		ls.Parent = sps
	end
end
