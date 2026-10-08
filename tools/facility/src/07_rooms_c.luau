
-- =============================================================================
-- STORAGE B  (packed warehouse, tall ceiling, overhead crane, loading dock)
-- =============================================================================
do
	local r = newRoom({ name = "StorageB", x0 = -46, x1 = -6, z0 = -84, z1 = -54, h = 20,
		floor = { mat = M.Concrete, color = C(92, 90, 86) }, wall = WALL.storage, damage = 0.5 })
	beams(r, "z", 10, 2.2)
	-- floor: worn concrete with painted lanes
	for _, x in ipairs({ -39, -31 }) do P.lineFloor(r, x - 0.15, x + 0.15, -82, -58, PAL.yellow) end
	P.lineFloor(r, -22.1, -21.9, -82, -56, PAL.yellow)
	P.lineFloor(r, -44, -8, -61.1, -60.9, PAL.yellow)
	P.hazardFloor(r, -25, -13, -83, -81.6) -- loading dock threshold

	-- warm caged lamps, many of them dying
	local y = r.h - 2.4
	local n = 0
	for _, z in ipairs({ -78, -66 }) do
		for _, x in ipairs({ -39, -29, -19, -11 }) do
			n += 1
			lampCage(r, x, y, z, WARM, 2.2, 32, { dead = (n % 5 == 0), flicker = (n % 4 == 0) and 0.8 or nil })
		end
	end

	-- overhead crane (landmark you can see from the corridor)
	for _, x in ipairs({ -42, -10 }) do bx(r.props, "CraneRail", x - 0.5, x + 0.5, 16.2, 17.2, -83, -55, M.Metal, PAL.yellow, { cc = false }) end
	bx(r.props, "CraneBridge", -43, -9, 15.2, 16.2, -71, -69, M.Metal, PAL.yellow, { cc = false })
	bx(r.props, "CraneTrolley", -27.5, -24.5, 14.4, 15.2, -71.5, -68.5, M.Metal, PAL.steelDark, { cc = false })
	cylY(r.props, "CraneChain", -26, 8.2, 14.4, -70, 0.35, M.Metal, PAL.steelDark, DECO)
	bx(r.props, "CraneHookBlock", -27, -25, 7.2, 8.2, -71, -69, M.Metal, PAL.yellow, { cc = false })
	P.hazardSign(r, "OVERHEAD CRANE\nWATCH LOADS", -45, 9, -70, 7, 1.8, "+x")

	-- shelving aisles
	P.shelf(r, -43, -82, -math.pi / 2, 4, 4, 0.9)
	P.shelf(r, -35, -82, -math.pi / 2, 4, 4, 0.9)
	P.shelf(r, -27, -82, -math.pi / 2, 3, 4, 0.9)
	P.hazardSign(r, "MAX LOAD\n500 KG / TIER", -39, 6.0, -58.3, 4.5, 1.4, "-z")

	-- freight zone, east side (keeps the door lane clear)
	P.crate(r, -9.8, 0, -81.5, 3.2, 3.2, 3.2, 0.2, "wood")
	P.crate(r, -9.8, 3.2, -81.5, 2.8, 2.4, 2.8, 0.5, "wood")
	P.crate(r, -14, 0, -81.5, 3.2, 2.8, 3.2, -0.1, "metal")
	P.crate(r, -22, 0, -79.5, 3, 2.6, 3, 0.3, "bio")
	P.pallet(r, -18, -80.5, 0.1)
	P.crate(r, -18, 0.75, -80.5, 2.6, 2.6, 2.6, 0.1, "cardboard")
	P.barrel(r, -8.6, -78.6)
	P.barrel(r, -8.6, -76.8, PAL.yellow)
	P.crate(r, -9.5, 0, -57.2, 4, 3.4, 3.2, 0.05, "wood")
	P.crate(r, -14, 0, -57.2, 3.2, 3.0, 3.0, 0.2, "bio")
	P.crate(r, -14, 3.0, -57.2, 2.6, 2.0, 2.6, -0.2, "wood")
	P.barrel(r, -18, -56.6)
	P.pallet(r, -40, -59.5, 0)
	P.forklift(r, -16, -63, math.pi)
	-- spilled barrels
	cylX(r.props, "BarrelLying", -20.4, -17.0, 1.1, -58.8, 2.2, M.Metal, PAL.rustDark)
	disc(r.story, "ToxicSpill", -16, 0.06, -58.8, 5.4, 0.05, M.Neon, C(60, 140, 50), { deco = true, tr = 0.6 })
	glow(r, -16, 1.2, -58.8, C(80, 220, 70), 0.7, 10)

	-- loading dock shutter (sealed) in the north wall
	bx(r.props, "DockFrame", -26, -12, 0, 11.2, -83, -82.6, M.Metal, PAL.steelDark)
	bx(r.props, "DockShutter", -25, -13, 0, 10.2, -82.6, -82.3, M.CorrodedMetal, jitter(PAL.steel, 0.1))
	for i = 1, 9 do bx(r.props, "DockSlat", -25, -13, i * 1.1 - 0.1, i * 1.1, -82.3, -82.2, M.Metal, PAL.steelDark, DECO) end
	P.hazardSign(r, "LOADING DOCK B\nKEEP CLEAR", -19, 12.6, -83, 9, 1.8, "+z")
	P.cctv(r, -44.7, 14, -56, "+x")
	P.cctv(r, -7.3, 14, -80, "-x", "dead")
	P.panel(r, -7.1, 3.2, -64, "-x", 2.0, 3.2, "open")
	P.extinguisher(r, -7.4, -73, "-x")
	P.exitSign(r, -27, 11.6, -55.1, "-z", "EXIT")

	-- mess
	P.papers(r, -30, -62, 5, 8)
	P.rubble(r, -38, -60, 3, 6)
	P.stain(r, -28, -70, 6, 5, 0.3)
	P.stain(r, -14, -70, 5, 4, 1.0)
	P.puddle(r, -33, -66, 3.4)
	P.drain(r, -22, -69)
	emitter(r, -33, 14, -70, "drip", { rate = 2 })
	emitter(r, -26, 8, -70, "dust", { size = Vector3.new(34, 14, 22), rate = 5 })
end

-- =============================================================================
-- MAINTENANCE / POWER  (dark, warm, reactor landmark, catwalk)
-- =============================================================================
do
	local r = newRoom({ name = "Maintenance", x0 = 6, x1 = 46, z0 = -84, z1 = -54, h = 18,
		floor = { mat = M.DiamondPlate, color = C(66, 68, 68) }, wall = WALL.maint, damage = 0.7 })
	beams(r, "x", 11, 1.8, PAL.rustDark)
	floorZone(r, "ConcretePatch", 7, 17, -83, -55, M.Concrete, C(70, 68, 62))
	P.lineFloor(r, 7, 45, -62.1, -61.9, PAL.yellow)

	-- the reactor: orange glow is the main light source in the room
	P.reactor(r, 26, -69, 10, 15)
	for _, a in ipairs({ 0, 1.57, 3.14, 4.71 }) do
		local px, pz = 26 + math.cos(a) * 9.4, -69 + math.sin(a) * 9.4
		cylY(r.props, "ReactorBollard", px, 0, 3, pz, 1.2, M.Metal, PAL.yellow)
	end
	P.hazardSign(r, "REACTOR  COOLING LOOP B\nHIGH VOLTAGE", 26, 11, -82.9, 10, 2.2, "+z")
	local y = r.h - 2.2
	lampCage(r, 12, y, -62, WARM, 1.6, 26, { dead = true })
	lampCage(r, 14, y, -76, WARM, 1.6, 26, { flicker = 0.9 })
	lampCage(r, 38, y, -62, WARM, 1.6, 26, {})
	lampCage(r, 36, y, -78, WARM, 1.4, 24, { flicker = 0.5 })
	lampRed(r, 7.3, 12, -60, "+x")
	lampRed(r, 44.7, 12, -60, "-x")

	-- upper level catwalk + stairs
	P.catwalk(r, 38, 45, -83, -65.6, 6, { w = true, n = true, e = true })
	P.stairs(r, 41.5, -55.2, math.pi, 3.5, 0.75, 8, 1.3)
	P.crate(r, 42.5, 6, -80, 2.4, 2, 2.4, 0.3, "metal")
	P.panel(r, 38.1, 7.6, -74, "+x", 2, 3, "open")

	-- generators + tool storage
	P.generator(r, 12, -80.4, "+z", 6, 4, 5)
	P.generator(r, 19, -80.4, "+z", 6, 4, 5)
	P.lockers(r, 7, -56, "+x", 5)
	P.cabinet(r, 8.4, -78, "+x", 3.4, 6, 1.8, jitter(PAL.rust, 0.1))
	P.cabinet(r, 8.4, -74.8, "+x", 3.0, 6, 1.8, jitter(PAL.steel, 0.1))
	P.cart(r, 12.5, -59, "+z", true)
	P.cart(r, 19.5, -57.6, "+z", false)
	P.crate(r, 41.5, 0, -75, 2.6, 2.2, 2.6, 0.6, "metal")
	P.barrel(r, 44, -58)
	P.barrel(r, 44, -60.4)
	P.barrel(r, 42.5, -59.2, PAL.yellow)

	-- infrastructure overhead and on the walls
	P.pipeRun(r, "x", 7, 45, -60, 15.5, 1.4, PAL.rust, { valves = true })
	P.pipeRun(r, "x", 7, 45, -77.5, 14.5, 1.2, PAL.steelLight, { valves = true })
	P.pipeRun(r, "z", -83, -55, 9, 13.8, 1.0, PAL.rust)
	P.pipeRun(r, "z", -83, -55, 43.5, 14.2, 0.9, PAL.rustDark)
	P.duct(r, "z", -83, -55, 15, 14.5, 3, 2.4)
	P.cableTray(r, "x", 7, 45, -66, 13.6, 2)
	P.cableTray(r, "z", -83, -55, 33.5, 12.9, 1.6)
	P.vent(r, 45, 6.5, -58, "-x", 2.6, 1.6)
	P.fan(r, 7.1, 10, -70, "+x", 3)
	P.fan(r, 45, 10, -66, "-x", 3)
	P.panel(r, 14, 3.3, -83, "+z", 2.2, 3.6, "open")
	P.panel(r, 30, 3.3, -83, "+z", 2.2, 3.6)
	P.cctv(r, 7.3, 14, -58, "+x")
	P.exitSign(r, 29, 12.4, -55.1, "-z", "EXIT")

	-- steam and water
	emitter(r, 10, 0.4, -57.2, "steam", { dir = NID.Top, rate = 8 })
	emitter(r, 40.5, 0.4, -72, "steam", { dir = NID.Top, rate = 6 })
	cylY(r.props, "SteamVent", 10, 0, 0.6, -57.2, 1.6, M.Metal, PAL.steelDark, DECO)
	cylY(r.props, "SteamVent", 40.5, 0, 0.6, -72, 1.6, M.Metal, PAL.steelDark, DECO)
	emitter(r, 21, 15.0, -60, "drip", { rate = 2 })
	P.puddle(r, 21, -57, 4)
	P.puddle(r, 35, -71, 3.2)
	P.stain(r, 24, -80, 10, 3, 0.1)
	P.rubble(r, 38, -58, 3, 8)
	P.papers(r, 14, -66, 4, 6)
	P.drain(r, 21, -66)
	emitter(r, 26, 8, -69, "dust", { size = Vector3.new(36, 14, 24), rate = 4 })
end

-- =============================================================================
-- SERVICE HALLWAY (narrow, pipe-choked, optional route toward the restricted wing)
-- =============================================================================
do
	local r = newRoom({ name = "ServiceHallA", x0 = 30, x1 = 38, z0 = -110, z1 = -84, h = 8,
		floor = { mat = M.DiamondPlate, color = C(62, 64, 62) }, wall = WALL.service, damage = 0.8 })
	P.pipeRun(r, "z", -109, -85, 31.9, 5.9, 0.9, PAL.rust, { valves = true })
	P.pipeRun(r, "z", -109, -85, 36.1, 6.4, 0.7, PAL.steelLight)
	P.pipeRun(r, "z", -109, -85, 36.1, 4.4, 0.5, PAL.rustDark)
	P.cableTray(r, "z", -109, -85, 34, 7.3, 1.4)
	lampCage(r, 34, 7.3, -90, WARM, 1.2, 14, {})
	lampCage(r, 34, 7.3, -98, WARM, 1.0, 14, { flicker = 0.9 })
	lampCage(r, 34, 7.3, -106, WARM, 1.0, 14, { dead = true })
	lampRed(r, 36.7, 5.2, -100, "-x", { bright = 1.2, range = 12 })
	P.vent(r, 31.05, 3, -95, "+x", 2, 1.2)
	P.panel(r, 36.9, 3.0, -92, "-x", 1.8, 3.0, "open")
	P.hazardSign(r, "SERVICE HALLWAY\nAUTHORIZED STAFF ONLY", 36.95, 4.6, -97, 4.5, 1.4, "-x")
	P.cart(r, 34.4, -88.2, "-z", true)
	emitter(r, 34, 0.3, -101, "steam", { dir = NID.Top, rate = 5 })
	P.puddle(r, 33, -94, 2.4)
	P.drain(r, 34, -97)
	P.papers(r, 34, -103, 2, 5)
	P.stain(r, 34, -100, 4, 5, 0.1)
	cylY(r.props, "SteamVent", 34, 0, 0.5, -101, 1.4, M.Metal, PAL.steelDark, DECO)
end

do
	local r = newRoom({ name = "ServiceHallB", x0 = 22, x1 = 30, z0 = -110, z1 = -102, h = 8,
		floor = { mat = M.DiamondPlate, color = C(62, 64, 62) }, wall = WALL.service, damage = 0.8 })
	lampRed(r, 26, 6.8, -102.9, "-z")
	lampCage(r, 26, 7.3, -106, WARM, 0.9, 12, { flicker = 0.9 })
	P.pipeRun(r, "x", 23, 29, -109, 5.4, 0.9, PAL.rust, { valves = true })
	P.panel(r, 26, 3.0, -109, "+z", 2.2, 3.0, "open")
	P.restrictedSign(r, "RESTRICTED\nSERVICE ACCESS", 29.95, 5.4, -108.2, 4, 1.6, "-x")
	P.rubble(r, 26, -106, 1.8, 4)
	P.papers(r, 26, -105, 1.5, 4)
	P.blood(r, 25, -105, 1.8)
end
