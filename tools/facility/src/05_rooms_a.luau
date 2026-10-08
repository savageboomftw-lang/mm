
-- ===========================================================================
--  ROOMS
-- ===========================================================================
local WALL = {
	lobby = { mat = M.Concrete, color = C(142, 140, 132), wain = { h = 5, mat = M.Metal, color = C(58, 64, 68) }, trim = PAL.steelDark, pil = { every = 12 },
		panels = { w = 4.5, shade = 0.86 }, accent = { y = 9.4, h = 0.45, mat = M.Metal, color = PAL.blue } },
	sec = { mat = M.Concrete, color = C(150, 152, 150), wain = { h = 4, mat = M.Metal, color = PAL.steelDark }, trim = PAL.steelDark, pil = { every = 10 },
		accent = { y = 6.0, h = 0.25, mat = M.Neon, color = shade(PAL.red, 0.5) } },
	corr = { mat = M.Concrete, color = C(128, 130, 124), wain = { h = 4.4, mat = M.CeramicTiles, color = PAL.tileWhite }, trim = PAL.tileGreen },
	lab = { mat = M.Plaster, color = C(148, 162, 170), wain = { h = 4.6, mat = M.CeramicTiles, color = C(190, 204, 204) }, trim = PAL.blue, pil = { every = 12 },
		accent = { y = 6.4, h = 0.22, mat = M.Neon, color = shade(PAL.cyan, 0.4) } },
	med = { mat = M.Plaster, color = C(128, 158, 140), wain = { h = 4.8, mat = M.CeramicTiles, color = PAL.tileWhite }, trim = PAL.tileDark, pil = { every = 12, color = C(118, 146, 130) } },
	storage = { mat = M.Concrete, color = C(104, 102, 96), trim = PAL.steelDark, pil = { every = 10, color = C(86, 84, 80) } },
	maint = { mat = M.Concrete, color = C(86, 80, 72), wain = { h = 3.2, mat = M.CorrodedMetal, color = PAL.rustDark }, trim = PAL.rustDark, pil = { every = 11, color = C(70, 66, 60) } },
	service = { mat = M.Concrete, color = C(80, 76, 70), trim = PAL.rustDark },
	decon = { mat = M.Concrete, color = C(150, 156, 156), wain = { h = 6, mat = M.CeramicTiles, color = C(168, 184, 184) }, trim = PAL.steelDark },
	restricted = { mat = M.Concrete, color = C(68, 68, 70), wain = { h = 7, mat = M.DiamondPlate, color = PAL.steelDark }, trim = PAL.black, pil = { every = 11, color = C(52, 52, 56) },
		panels = { w = 5, shade = 0.9 }, accent = { y = 11, h = 0.3, mat = M.Neon, color = shade(PAL.red, 0.45) } },
	lift = { mat = M.Concrete, color = C(96, 98, 96), wain = { h = 4, mat = M.Metal, color = PAL.steelDark }, trim = PAL.green },
}
local WHITE = C(255, 246, 230)
local COLD = C(214, 232, 255)
local WARM = C(255, 206, 140)

-- small helpers used by several rooms -----------------------------------------
local function vending(r, x, z, facing, tint)
	local cf = frame(x, 0, z, facing)
	lp(r.props, "VendBody", cf, 0, 3.3, 0, 3.2, 6.6, 2.6, M.Metal, tint or C(150, 40, 40))
	local scr = lp(r.props, "VendPanel", cf, -0.3, 3.7, 1.32, 2.2, 3.8, 0.1, M.Neon, C(150, 190, 210), DECO)
	lp(r.props, "VendSlot", cf, -0.3, 1.0, 1.32, 2.2, 0.8, 0.1, M.Metal, PAL.black, DECO)
	tag(scr, "FlickerLight")
	scr:SetAttribute("Flicker", 0.25)
end
local function cageBox(r, x0, x1, z0, z1, h, gaps) -- chain-link-ish security cage; gaps = { {axis,a0,a1} }
	local function side(axis, f, a0, a1, gap)
		local segs = {}
		if gap then
			if gap[1] > a0 then segs[#segs + 1] = { a0, gap[1] } end
			if gap[2] < a1 then segs[#segs + 1] = { gap[2], a1 } end
			bx(r.props, "CageTop", axis == "x" and gap[1] or f - 0.1, axis == "x" and gap[2] or f + 0.1, h - 0.4, h,
				axis == "x" and f - 0.1 or gap[1], axis == "x" and f + 0.1 or gap[2], M.Metal, PAL.steelDark, DECO)
		else
			segs[1] = { a0, a1 }
		end
		for _, s in ipairs(segs) do
			slab(r.props, "CageMesh", axis, s[1], s[2], 0.4, h - 0.4, f - 0.06, f + 0.06, M.Metal, PAL.steel, { tr = 0.55, shadow = false })
			slab(r.props, "CageRail", axis, s[1], s[2], 0, 0.4, f - 0.15, f + 0.15, M.Metal, PAL.steelDark, { shadow = false })
			slab(r.props, "CageRail", axis, s[1], s[2], h - 0.4, h, f - 0.15, f + 0.15, M.Metal, PAL.steelDark, { shadow = false })
			local a = s[1]
			while a <= s[2] + 0.01 do
				slab(r.props, "CagePost", axis, a - 0.12, a + 0.12, 0, h, f - 0.15, f + 0.15, M.Metal, PAL.steelDark, { shadow = false })
				a += 5
			end
		end
	end
	local g = gaps or {}
	side("x", z0, x0, x1, g.n)
	side("x", z1, x0, x1, g.s)
	side("z", x0, z0, z1, g.w)
	side("z", x1, z0, z1, g.e)
end

-- =============================================================================
-- RECEPTION  (hero: official entrance, mostly intact, just evacuated)
-- =============================================================================
do
	local r = newRoom({ name = "Reception", x0 = -25, x1 = 25, z0 = 0, z1 = 36, h = 18,
		floor = { mat = M.Marble, color = C(152, 150, 142) }, wall = WALL.lobby, damage = 0.2 })
	floorZone(r, "CarpetRunner", -3.2, 3.2, 1, 35, M.Fabric, C(52, 66, 74))
	floorZone(r, "CarpetEdge", -3.4, -3.2, 1, 35, M.Fabric, PAL.yellow)
	floorZone(r, "CarpetEdge", 3.2, 3.4, 1, 35, M.Fabric, PAL.yellow)
	disc(r.arch, "FloorLogo", 0, 0.05, 18, 12, 0.06, M.Metal, PAL.steelDark, DECO)
	disc(r.arch, "FloorLogoRing", 0, 0.08, 18, 10.4, 0.06, M.Neon, shade(PAL.cyan, 0.45), DECO)
	disc(r.arch, "FloorLogoInner", 0, 0.1, 18, 9.6, 0.06, M.Metal, PAL.steelDark, DECO)
	beams(r, "x", 9, 1.6)
	column(r, -13, 20, 2.4, 18, M.Concrete, C(120, 118, 112))
	column(r, 13, 20, 2.4, 18, M.Concrete, C(120, 118, 112))
	column(r, -13, 8, 2.4, 18, M.Concrete, C(120, 118, 112))
	column(r, 13, 8, 2.4, 18, M.Concrete, C(120, 118, 112))

	-- lighting: neutral white, a couple of tubes failing
	local y = r.h - 1.7
	for _, z in ipairs({ 5, 15, 26 }) do
		for _, x in ipairs({ -10, 10 }) do
			local f = (z == 15 and x == 10) and 0.5 or nil
			lampStrip(r, x, y, z, "x", 8, WHITE, 1.5, 30, { flicker = f, dead = (z == 26 and x == -10) })
		end
	end
	lampWall(r, -24, 7, 8, "+x", WARM, 0.8, 14)
	lampWall(r, 24, 7, 8, "-x", WARM, 0.8, 14)
	lampWall(r, -24, 7, 28, "+x", WARM, 0.7, 14, { flicker = 0.4 })
	lampWall(r, 24, 7, 28, "-x", WARM, 0.7, 14)

	-- north wall: facility logo above the checkpoint gate
	cylZ(r.props, "LogoDisc", 1.0, 1.35, 0, 15.0, 4.4, M.Metal, PAL.steelDark, DECO)
	cylZ(r.props, "LogoRing", 1.0, 1.5, 0, 15.0, 4.9, M.Neon, shade(PAL.cyan, 0.5), DECO)
	cylZ(r.props, "LogoCore", 1.35, 1.6, 0, 15.0, 2.2, M.Metal, PAL.blue, DECO)
	P.sign(r, "HALCYON  RESEARCH  STATION", 0, 11.9, 1.0, 17, 1.5, "+z", PAL.blueDark, PAL.offwhite, { font = Enum.Font.GothamBlack })
	-- banners between the pilasters (one has come down), status screens
	for sx, zs in pairs({ [-1] = { 9, 33 }, [1] = { 7, 21, 31 } }) do
		for _, z in ipairs(zs) do
			local bx0 = sx * 23.7
			cb(r.props, "Banner", bx0, 11, z, 0.12, 8, 2.6, 0, M.Fabric, PAL.blueDark, DECO)
			cb(r.props, "BannerEmblem", bx0 - sx * 0.08, 12.5, z, 0.06, 2.0, 1.4, 0, M.SmoothPlastic, shade(PAL.cyan, 0.55), DECO)
		end
	end
	cb(r.story, "FallenBanner", -18, 0.08, 20.5, 2.6, 0.06, 8, 0.5, M.Fabric, PAL.blueDark, DECO)
	local scr = P.sign(r, "FACILITY STATUS\nLEVEL 3 BREACH\nALL SYSTEMS OFFLINE", 24, 11, 26, 5, 2.6, "-x", C(8, 24, 20), PAL.green, { font = Enum.Font.Code, glow = true })
	tag(scr, "Screen")
	P.sign(r, "ENTRANCE SEALED  -  LOCKDOWN IN EFFECT", 0, 14.6, 35, 15, 1.8, "-z", PAL.red, PAL.offwhite, { font = Enum.Font.GothamBlack })

	-- reception counter with enclosed back office
	bx(r.props, "DeskFront", -22, -8, 0, 3.7, 10, 11, M.Metal, C(58, 66, 70))
	bx(r.props, "DeskTop", -22.4, -7.6, 3.7, 4.0, 9.4, 11.4, M.Granite, C(36, 38, 40))
	bx(r.props, "DeskSide", -22.4, -21.4, 0, 3.7, 3, 10, M.Metal, C(58, 66, 70))
	bx(r.props, "DeskSideTop", -22.6, -21.2, 3.7, 4.0, 3, 10, M.Granite, C(36, 38, 40))
	P.sign(r, "VISITOR  RECEPTION", -15, 2.0, 11.0, 8, 1.2, "+z", PAL.blueDark, PAL.offwhite)
	P.monitor(r, -17, 4.0, 9.8, "-z", "on")
	P.monitor(r, -12, 4.0, 9.8, "-z", "broken")
	P.monitor(r, -20, 4.0, 9.8, "-z", "off")
	P.chair(r, -16.5, 7.2, "+z", true)
	P.cabinet(r, -20, 2.1, "+z", 3.2, 6.4, 1.6)
	P.cabinet(r, -16.4, 2.1, "+z", 3.2, 6.4, 1.6)
	P.cabinet(r, -12.8, 2.1, "+z", 3.2, 6.4, 1.6)

	-- notices, directory, posters
	P.restrictedSign(r, "LEVEL 3 CONTAINMENT BREACH\nEVACUATE IMMEDIATELY", -24, 9, 16, 6, 3, "+x")
	P.sign(r, "VISITOR DIRECTORY\nSECURITY ........ L1\nBIOLOGICAL RES. .. L2\nMEDICAL / RECOVERY L2\nSTORAGE B ........ L2\nMAINTENANCE ...... L2\nCONTAINMENT ... RESTRICTED",
		24, 9, 14, 7, 5.2, "-x", PAL.blueDark, PAL.offwhite, { font = Enum.Font.Code })
	P.poster(r, -24, 8, 20, "+x", 1)
	P.poster(r, -24, 8, 23, "+x", 5)
	P.extinguisher(r, -23.4, 12, "+x")
	P.extinguisher(r, 23.4, 30, "-x")
	vending(r, -22.6, 30, "+x", C(150, 40, 40))
	vending(r, -22.6, 26.2, "+x", C(40, 90, 150))
	P.bench(r, 12, 22, "+z", 8, false)
	P.bench(r, 14, 27, "+z", 7, true)
	P.cctv(r, -23.7, 14.5, 4, "+x")
	P.cctv(r, 23.7, 14.5, 32, "-x", "dead")

	-- story: people left in a hurry, someone didn't make it to the door
	P.papers(r, -6, 22, 8, 16)
	P.papers(r, 6, 12, 6, 10)
	P.papers(r, -15, 12, 6, 12)
	P.papers(r, 16, 25, 5, 8)
	P.drag(r, 1.5, 5, 2.4, 32)
	P.blood(r, 2.2, 32.5, 3)
	P.bloodWall(r, -1.5, 7.3, 34.5, "-z", 3)
	P.bloodWall(r, 1.8, 5.8, 34.5, "-z", 2.5)
	P.bloodWall(r, 3.4, 8.1, 34.5, "-z", 3.2)
	P.stain(r, -5, 25, 6, 4, 0.3)
	P.stain(r, 12, 10, 5, 3, 1.1)
	P.puddle(r, -2, 29, 3.5)
	emitter(r, 0, 9, 18, "dust", { size = Vector3.new(40, 10, 28), rate = 4 })
end

-- =============================================================================
-- SECURITY CHECKPOINT  (clean, militarised, strong light with red accents)
-- =============================================================================
do
	local r = newRoom({ name = "Security", x0 = -15, x1 = 15, z0 = -24, z1 = 0, h = 12,
		floor = { mat = M.Concrete, color = C(124, 126, 124) }, wall = WALL.sec, damage = 0.3 })
	dropCeiling(r, r.h - 1.0, 0.05, C(168, 172, 170))
	local y = r.h - 1.15
	for _, z in ipairs({ -4, -12, -19 }) do
		for _, x in ipairs({ -8, 8 }) do
			lampStrip(r, x, y, z, "x", 7, C(250, 252, 255), 1.7, 26, { flicker = (x == 8 and z == -12) and 0.6 or nil, dead = (x == -8 and z == -19) })
		end
	end
	lampRed(r, -6.5, 8.8, -23, "+z")
	lampRed(r, 6.5, 8.8, -23, "+z")

	-- checkpoint lanes
	P.detector(r, -4, -5, "+z", true)
	P.detector(r, 4, -5, "+z", false)
	P.jersey(r, -10.5, -5, "+z", 7)
	P.jersey(r, 10.5, -5, "+z", 7)
	P.lineFloor(r, -6.1, -5.9, -9, -1)
	P.lineFloor(r, 5.9, 6.1, -9, -1)
	P.lineFloor(r, -0.1, 0.1, -9, -1)
	P.lineFloor(r, -14, 14, -9.2, -8.9)

	-- control desk + CCTV wall
	P.console(r, 7, -13, "+z", 7, { "on", "broken", "on" })
	P.chair(r, 9, -10.4, "+z", true)
	bx(r.props, "CCTVDesk", 12, 14, 0, 3.4, -22.5, -14.5, M.Metal, PAL.steelDark)
	local states = { "on", "on", "broken", "off", "on", "on" }
	local k = 1
	for _, yr in ipairs({ 4.6, 7.0 }) do
		for _, zc in ipairs({ -21, -18.2, -15.4 }) do
			P.monitor(r, 13.8, yr, zc, "-x", states[k])
			k += 1
		end
	end
	P.infoSign(r, "CCTV CONTROL", 14, 10.2, -18.2, 6, 1, "-x")

	-- armoury cage (uncommon chest spot) + lockers
	cageBox(r, -14, -7, -22, -15, 7.5, { e = { -20, -17 } })
	P.shelf(r, -12.6, -22.5, -math.pi / 2, 1, 2, 0.6)
	P.cabinet(r, -9.2, -21.6, "+z", 2.4, 6.2, 2.2)
	P.restrictedSign(r, "SECURITY EQUIPMENT\nAUTHORIZED ONLY", -14, 8.5, -18.5, 5, 1.8, "+x")
	P.lockers(r, -14, -3, "+x", 5)
	P.poster(r, -14, 8.6, -9, "+x", 4)

	-- last stand at the blast door
	P.sandbag(r, 5, -19.5, "+z", 4)
	P.hazardFloor(r, -4, 4, -22.8, -20.6)
	P.blood(r, 9, -10, 2.5)
	P.drag(r, 8, -11.5, 3, -19)
	P.papers(r, 0, -14, 7, 14)
	P.papers(r, -4, -3, 4, 6)
	P.cctv(r, -13.6, 10.5, -2, "+x")
	P.cctv(r, 13.6, 10.5, -2, "-x", "dead")
	P.extinguisher(r, 13.4, -2.6, "-x")
	P.exitSign(r, 0, 10.4, -22.9, "+z", "EXIT")
	P.stain(r, -3, -15, 5, 3, 0.4)
end

-- =============================================================================
-- MAIN CORRIDOR A  (spine of the facility: tiled, long, lights failing northward)
-- =============================================================================
do
	local r = newRoom({ name = "MainCorridor", x0 = -6, x1 = 6, z0 = -84, z1 = -24, h = 11,
		floor = { mat = M.Concrete, color = C(94, 94, 90) }, wall = WALL.corr, damage = 0.45 })
	dropCeiling(r, r.h - 1.2, 0.09, C(172, 174, 168))
	floorZone(r, "Walkway", -2.2, 2.2, -83, -25, M.Rubber, C(66, 70, 68))
	floorZone(r, "WalkEdge", -2.4, -2.2, -83, -25, M.SmoothPlastic, PAL.yellow)
	floorZone(r, "WalkEdge", 2.2, 2.4, -83, -25, M.SmoothPlastic, PAL.yellow)
	local y = r.h - 1.35
	for i, z in ipairs({ -30, -40, -50, -60, -70, -80 }) do
		lampStrip(r, 0, y, z, "z", 6, COLD, 1.5, 24, { flicker = (i == 3) and 0.5 or (i == 5 and 0.9 or nil), dead = (i == 4) })
	end
	P.pipeRun(r, "z", -83, -25, 4.3, 8.6, 0.7, PAL.steelLight, { valves = true })
	P.pipeRun(r, "z", -83, -25, 4.3, 7.3, 0.4, PAL.rust)
	P.cableTray(r, "z", -83, -25, -4.2, 8.9, 1.6)
	P.vent(r, -4.95, 6.2, -58, "+x", 2.4, 1.4)
	P.vent(r, 4.95, 6.2, -31, "-x", 2.4, 1.4)
	P.panel(r, 4.9, 3.0, -48, "-x", 1.8, 3.0, "open")
	P.panel(r, -4.9, 3.0, -64, "+x", 1.8, 3.0)
	P.fan(r, 4.95, 6.6, -66, "-x", 2.4)

	-- benches, carts, extinguishers: a lived-in hall
	P.bench(r, -3.9, -28, "+x", 6, false)
	P.bench(r, 3.9, -47, "-x", 6, true)
	P.cart(r, 3.4, -61.5, "+z", true)
	P.cart(r, -3.6, -80.5, "+x", false)
	P.extinguisher(r, 4.5, -33, "-x")
	P.extinguisher(r, -4.5, -78, "+x")
	P.poster(r, -5, 7.4, -30, "+x", 2)
	P.poster(r, 5, 7.4, -60, "-x", 1)
	P.infoSign(r, "SECTOR C  -  LEVEL 2", -5, 9.2, -39, 5.5, 1.1, "+x")
	P.exitSign(r, 0, 9.4, -26, "+z", "EXIT")
	P.cctv(r, -4.9, 9.6, -30, "+x")
	P.cctv(r, 4.9, 9.6, -70, "-x", "dead")
	lampRed(r, 4.9, 8.0, -80, "-x")

	-- the deeper north end is in worse shape
	P.rubble(r, -3.5, -60, 2.5, 7)
	P.rubble(r, 3.5, -57, 2.0, 6)
	P.rubble(r, -3, -81, 1.8, 6, true)
	P.drag(r, 2.2, -68, 0, -82)
	P.blood(r, 0.5, -81, 3)
	P.papers(r, 0, -45, 4, 14)
	P.papers(r, 0, -72, 4, 10)
	P.puddle(r, -1, -64, 3.2)
	P.puddle(r, 2, -38, 2.4)
	P.stain(r, -2, -54, 4, 5, 0.2)
	P.drain(r, 0, -48)
	emitter(r, -2.5, 9.0, -57, "drip", {})
	emitter(r, 1, 9.0, -63, "drip", { rate = 2 })
end
