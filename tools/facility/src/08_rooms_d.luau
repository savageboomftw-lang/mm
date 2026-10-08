
local function hazmat(r, x, z, facing)
	local cf = frame(x, 0, z, facing)
	lp(r.props, "HazmatBody", cf, 0, 3.6, 0, 1.8, 3.2, 1.0, M.Fabric, PAL.orange, DECO)
	lp(r.props, "HazmatLegs", cf, 0, 1.2, 0, 1.5, 2.4, 0.9, M.Fabric, shade(PAL.orange, 0.85), DECO)
	lp(r.props, "HazmatArms", cf, 0, 3.7, 0.1, 2.6, 0.6, 0.6, M.Fabric, PAL.orange, DECO)
	mk(r.props, "HazmatHelmet", Vector3.new(1.2, 1.3, 1.2), cf * CFrame.new(0, 5.6, 0), M.Glass, C(150, 170, 150), { deco = true, tr = 0.4, shape = SHAPE_BALL })
end

-- =============================================================================
-- DECONTAMINATION AIRLOCK  (restricted corridor: tight, red/white, wet)
-- =============================================================================
do
	local r = newRoom({ name = "Decon", x0 = -6, x1 = 6, z0 = -96, z1 = -84, h = 9,
		floor = { mat = M.CeramicTiles, color = C(150, 162, 160) }, wall = WALL.decon, damage = 0.6 })
	floorZone(r, "DrainChannel", -0.5, 0.5, -95, -85, M.Metal, PAL.steelDark)
	P.hazardFloor(r, -4, 4, -87.4, -85.1)
	P.hazardFloor(r, -4, 4, -94.9, -92.6)
	lampStrip(r, 0, r.h - 0.1, -90, "x", 5, C(235, 245, 255), 1.3, 14, { flicker = 0.9 })
	lampRed(r, -4.8, 7.4, -86.5, "+x", { bright = 1.6, range = 14 })
	lampRed(r, 4.8, 7.4, -93.5, "-x", { bright = 1.6, range = 14 })
	-- ceiling spray rail
	P.pipeRun(r, "z", -95, -85, -2.5, 8.2, 0.5, PAL.steelLight)
	P.pipeRun(r, "z", -95, -85, 2.5, 8.2, 0.5, PAL.steelLight)
	for _, z in ipairs({ -93.5, -91, -88.5, -86.2 }) do
		for _, x in ipairs({ -2.5, 2.5 }) do cylY(r.props, "SprayNozzle", x, 7.5, 8.0, z, 0.5, M.Metal, PAL.steelDark, DECO) end
	end
	P.hazardSign(r, "DECONTAMINATION CYCLE\nMANDATORY", -5, 6.2, -90, 6, 2, "+x")
	P.restrictedSign(r, "NO ENTRY\nBIOHAZARD", 5, 6.2, -90, 4, 2, "-x")
	hazmat(r, -4.3, -87, "+x")
	hazmat(r, -4.3, -93, "+x")
	P.drain(r, 0, -90)
	P.drain(r, 0, -87.6)
	P.puddle(r, 2, -89, 3)
	P.puddle(r, -2.4, -92, 2.2)
	P.stain(r, 0, -91, 4, 4, 0.2)
	emitter(r, 0, 8.6, -90, "drip", { rate = 3 })
	emitter(r, 2.5, 0.4, -86.5, "steam", { dir = NID.Top, rate = 5 })
	cylY(r.props, "SteamVent", 2.5, 0, 0.5, -86.5, 1.2, M.Metal, PAL.steelDark, DECO)
	P.blood(r, 1, -94, 2.5)
	P.drag(r, 0.5, -89, 0, -95)
end

-- =============================================================================
-- RESTRICTED CONTAINMENT AREA  (hero: breached chamber, red emergency lighting)
-- =============================================================================
do
	local r = newRoom({ name = "Containment", x0 = -22, x1 = 22, z0 = -136, z1 = -96, h = 26,
		floor = { mat = M.DiamondPlate, color = C(48, 50, 54) }, wall = WALL.restricted, damage = 0.85 })
	beams(r, "x", 10, 2.4, C(40, 40, 44))
	floorZone(r, "ReinforcedPad", -4.2, 4.2, -105, -97, M.Metal, C(36, 38, 42))
	P.hazardFloor(r, -4, 4, -100.2, -97.8)
	P.hazardFloor(r, -4, 4, -134.2, -131.8)

	-- the chamber: shattered cylinder, something big left through the breach
	local cx, cz = 0, -116
	cylY(r.props, "ChamberPlinth", cx, 0, 1.0, cz, 23, M.Metal, C(40, 42, 46))
	disc(r.props, "ChamberHazardRing", cx, 1.03, cz, 22, 0.05, M.SmoothPlastic, PAL.yellow, DECO)
	disc(r.props, "ChamberHazardInner", cx, 1.06, cz, 20.2, 0.05, M.Metal, C(40, 42, 46), DECO)
	cylY(r.props, "ChamberBase", cx, 1.0, 2.2, cz, 15, M.Metal, PAL.steelDark)
	cylY(r.props, "ChamberGlassLow", cx, 2.2, 8, cz, 14, M.Glass, C(190, 215, 215), { tr = 0.78, refl = 0.1, shadow = false })
	cylY(r.props, "ChamberRing", cx, 8, 8.8, cz, 14.6, M.Metal, PAL.steelDark)
	cylY(r.props, "ChamberRing", cx, 15.2, 16, cz, 14.6, M.Metal, PAL.steelDark)
	cylY(r.props, "ChamberGlassHigh", cx, 16, 23, cz, 14, M.Glass, C(190, 215, 215), { tr = 0.8, refl = 0.1, shadow = false })
	cylY(r.props, "ChamberCap", cx, 23, 24.2, cz, 15, M.Metal, PAL.steelDark)
	for i = 0, 3 do -- structural struts holding the broken middle section
		local a = i * math.pi / 2 + 0.4
		cylY(r.props, "ChamberStrut", cx + math.cos(a) * 6.9, 8.8, 15.2, cz + math.sin(a) * 6.9, 0.7, M.Metal, PAL.steel, { shadow = false })
	end
	cylY(r.props, "ChamberCore", cx, 2.2, 23, cz, 2.6, M.Metal, PAL.steelDark, DECO)
	local core = disc(r.props, "ChamberGlowPlate", cx, 2.3, cz, 11, 0.15, M.Neon, C(150, 20, 16), { deco = true, tr = 0.35 })
	addLight("point", core, C(255, 40, 30), 2.6, 38, { shadows = false })
	tag(core, "PulseLight")
	core:SetAttribute("Speed", 0.9)
	for i = 0, 3 do -- coolant lines from the cap to the ceiling
		local a = i * math.pi / 2 + math.pi / 4
		cylY(r.props, "ChamberPipe", cx + math.cos(a) * 5, 24.2, r.h, cz + math.sin(a) * 5, 1.5, M.Metal, PAL.steel, DECO)
	end
	P.shards(r, cx, cz, 12.5, 40)
	P.rubble(r, cx, cz, 11, 12)
	P.blood(r, 9, -113, 4)
	P.blood(r, -9, -123, 3.5)
	P.drag(r, 10, -112, 19, -106)
	P.claw(r, 20.9, 4.6, -112, "-x", 5)
	P.claw(r, 20.9, 4.4, -122, "-x", 4)
	P.restrictedSign(r, "CONTAINMENT AREA\nSUBJECT 07  -  BREACH", 0, 17, -135, 12, 3, "+z")
	emitter(r, cx, 22, cz, "spark", { every = 4, dir = NID.Bottom })
	emitter(r, cx, 0.5, cz, "steam", { size = Vector3.new(10, 0.5, 10), dir = NID.Top, rate = 5 })
	emitter(r, cx, 6, cz, "dust", { size = Vector3.new(30, 14, 30), rate = 6 })

	-- observation gallery (west) overlooking the chamber
	P.catwalk(r, -21, -14, -134, -109, 7, { e = true, n = true })
	P.stairs(r, -17.5, -97.3, math.pi, 3.5, 0.78, 9, 1.3)
	bx(r.props, "GalleryConsole", -21, -19.2, 7, 10.2, -131, -121, M.Metal, PAL.steelDark)
	P.monitor(r, -19.6, 10.2, -129.5, "+x", "on", PAL.red)
	P.monitor(r, -19.6, 10.2, -126.5, "+x", "broken")
	P.monitor(r, -19.6, 10.2, -123.5, "+x", "on")
	P.monitor(r, -19.6, 10.2, -121.6, "+x", "off")
	P.sign(r, "OBSERVATION GALLERY 2\nKEYCARD LEVEL 4", -21, 11.6, -112, 6, 1.6, "+x", PAL.red, PAL.offwhite)
	bx(r.props, "GalleryWindowSill", -21, -20.2, 7, 9.5, -108.8, -108.4, M.Metal, PAL.steelDark, DECO)

	-- pylons, machinery, wall plant
	for _, z in ipairs({ -113, -121 }) do
		cylY(r.props, "Pylon", 15.5, 0, r.h, z, 3.2, M.Metal, C(62, 64, 68))
		cylY(r.props, "PylonBand", 15.5, 9, 10.5, z, 3.5, M.Neon, shade(PAL.red, 0.7), DECO)
		cylY(r.props, "PylonBase", 15.5, 0, 1.2, z, 4.6, M.Concrete, PAL.concreteDark, DECO)
	end
	P.generator(r, 8, -133, "+z", 7, 3.4, 6)
	P.generator(r, 14, -133, "+z", 7, 3.4, 6)
	P.pipeRun(r, "x", -21, 21, -100, 22, 2.0, PAL.steelDark, { valves = true })
	P.pipeRun(r, "x", -21, 21, -133, 21, 1.6, PAL.rustDark)
	P.pipeRun(r, "z", -135, -97, 18, 20, 1.6, PAL.steelDark)
	P.cableTray(r, "x", -21, 21, -104, 19, 2.4)
	P.panel(r, 21, 3.0, -100, "-x", 2.2, 3.6, "open")
	P.panel(r, -20.9, 3.0, -100, "+x", 2.2, 3.6, "open")
	P.crate(r, 18, 0, -99, 3.2, 3, 3.2, 0.4, "metal")
	P.gurney(r, 17, -127, "+z", true)
	P.cart(r, 12, -101, "+z", true)
	-- hanging cables
	for i = 1, 7 do
		cylY(r.story, "HangingCable", rand(-18, 18), r.h - rand(4, 9), r.h, rand(-132, -100), 0.2, M.Rubber, PAL.black, DECO)
	end

	-- lighting: almost none but emergency red; one white tube stuttering over the gallery
	for _, p in ipairs({ { -20.9, -102 }, { -20.9, -132 }, { 20.9, -103 }, { 20.9, -133 } }) do
		lampRed(r, p[1], 14, p[2], p[1] < 0 and "+x" or "-x", { bright = 2.4, range = 30 })
	end
	lampRed(r, -8, 14, -135, "+z", { bright = 2.4, range = 30 })
	lampRed(r, 8, 14, -135, "+z", { bright = 2.4, range = 30 })
	lampStrip(r, -17.5, 24, -121, "z", 8, C(220, 230, 255), 1.4, 26, { flicker = 1.0 })
	lampCage(r, 15.5, 13, -100, C(255, 120, 80), 1.0, 20, { flicker = 0.6 })
	P.cctv(r, -20.7, 14.5, -105, "+x", "dead")
	P.cctv(r, 20.7, 14.5, -130, "-x")
	P.papers(r, 10, -128, 6, 12)
	P.papers(r, -10, -102, 5, 8)
	P.puddle(r, 14, -104, 3.5)
	P.stain(r, -10, -124, 8, 6, 0.4)
end

-- =============================================================================
-- EVACUATION LIFT  (the goal: safe green light after the red)
-- =============================================================================
do
	local r = newRoom({ name = "Extraction", x0 = -8, x1 = 8, z0 = -160, z1 = -136, h = 12,
		floor = { mat = M.Concrete, color = C(104, 106, 102) }, wall = WALL.lift, damage = 0.4 })
	beams(r, "x", 8, 1.4)
	floorZone(r, "PadFrame", -5.5, 5.5, -153.5, -142.5, M.Metal, C(52, 56, 54))
	disc(r.arch, "PadRing", 0, 0.08, -148, 10.6, 0.06, M.Neon, shade(PAL.green, 0.5), DECO)
	disc(r.arch, "PadInner", 0, 0.1, -148, 9.6, 0.06, M.Metal, C(52, 56, 54), DECO)
	P.lineFloor(r, -0.15, 0.15, -141.5, -137, PAL.green)
	P.hazardFloor(r, -4, 4, -139.6, -137.2)
	P.hazardFloor(r, -4, 4, -156.8, -154.6)
	-- lift cabin (open doors), landmark at the end
	bx(r.props, "LiftBack", -3.6, 3.6, 0, 9, -159, -158.4, M.Metal, PAL.steelDark)
	bx(r.props, "LiftSideW", -3.6, -3.2, 0, 9, -159, -153.6, M.Metal, PAL.steelDark)
	bx(r.props, "LiftSideE", 3.2, 3.6, 0, 9, -159, -153.6, M.Metal, PAL.steelDark)
	bx(r.props, "LiftCeiling", -3.6, 3.6, 9, 9.4, -159, -153.6, M.Metal, PAL.steelDark)
	bx(r.props, "LiftFrameHead", -4.8, 4.8, 9.4, 10.6, -159, -153.2, M.Metal, PAL.steelDark)
	bx(r.props, "LiftDoorLeaf", -4.8, -3.6, 0, 9.4, -154.4, -153.6, M.DiamondPlate, shade(PAL.steelDark, 1.2))
	bx(r.props, "LiftDoorLeaf", 3.6, 4.8, 0, 9.4, -154.4, -153.6, M.DiamondPlate, shade(PAL.steelDark, 1.2))
	local lp1 = bx(r.lights, "LiftLightPanel", -2.4, 2.4, 8.9, 9.0, -157.6, -154.6, M.Neon, C(220, 255, 230), DECO)
	addLight("surface", lp1, C(220, 255, 230), 1.6, 22, { shadows = false })
	P.sign(r, "EVACUATION LIFT", 0, 11.2, -153.2, 8, 1.1, "+z", PAL.green, PAL.offwhite, { font = Enum.Font.GothamBlack })
	P.sign(r, "LIFT STANDBY\nHOLD POSITION FOR EXTRACTION", 7, 6.4, -150, 5.5, 2.4, "-x", C(10, 30, 16), PAL.green, { font = Enum.Font.Code, glow = true })
	P.keycardReader(r, 6.9, 4.6, -156, "-x", "X-E", "unlocked")
	-- green = safe
	lampStrip(r, -4, r.h - 1.6, -143, "x", 6, C(190, 255, 205), 1.4, 20, {})
	lampStrip(r, 4, r.h - 1.6, -150, "x", 6, C(190, 255, 205), 1.4, 20, { flicker = 0.3 })
	lampStrip(r, 0, r.h - 1.6, -156, "x", 6, C(190, 255, 205), 1.2, 18, {})
	lampWall(r, -6.9, 7.5, -146, "+x", PAL.green, 0.8, 14)
	lampWall(r, 6.9, 7.5, -142, "-x", PAL.green, 0.8, 14, { noLight = true })
	P.exitSign(r, 0, 10.4, -137.2, "-z", "EXIT")
	-- aftermath: someone fought to hold the lift
	P.crate(r, -6, 0, -141, 2.4, 2.2, 2.4, 0.3, "metal")
	P.crate(r, -5.4, 0, -157.4, 2.6, 2.2, 2.6, 0.5, "wood")
	P.barrel(r, 5.8, -157.6, PAL.blueDark)
	P.bench(r, -6.4, -149, "+x", 5, false)
	P.blood(r, 1.5, -145, 3)
	P.drag(r, 0, -137, 2, -144)
	P.claw(r, -3.5, 4.0, -155.5, "+x", 4)
	P.papers(r, 0, -148, 5, 10)
	P.rubble(r, 5, -140, 2, 5)
	P.cctv(r, -6.7, 10.5, -138, "+x")
	P.extinguisher(r, 6.6, -141, "-x")
	emitter(r, 0, 5, -149, "dust", { size = Vector3.new(12, 8, 18), rate = 3 })
end
