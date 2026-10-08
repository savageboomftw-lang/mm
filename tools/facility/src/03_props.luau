
-- ---------------------------------------------------------------- props
-- Convention: prop(r, x, z, facing, ...) builds at floor level in room r.
-- facing is "+z" "-z" "+x" "-x" (or a yaw in radians). Rows extend along local +X,
-- the prop's front is local +Z.  Pass r.story as the room for narrative clutter.
local P = {}
local function lp(par, name, cf, ox, oy, oz, sx, sy, sz, mat, color, o)
	return mk(par, name, Vector3.new(sx, sy, sz), cf * CFrame.new(ox, oy, oz), mat, color, o)
end
local function frame(x, y0, z, f) return CFrame.new(x, y0, z) * CFrame.Angles(0, yawOf(f), 0) end
local DECO = { deco = true }
local SHAPE_BALL = Enum.PartType.Ball

function P.sign(r, text, x, y, z, w, h, facing, bg, fg, o)
	o = o or {}
	local yaw = yawOf(facing)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, 0.09)
	local p = mk(r.props, "Sign", Vector3.new(w, h, 0.15), cf, o.mat or M.SmoothPlastic, bg or PAL.steelDark, DECO)
	surfText(p, NID.Back, text, fg or PAL.offwhite, o)
	return p
end
-- yellow hazard / red restricted plates
function P.hazardSign(r, text, x, y, z, w, h, facing) return P.sign(r, text, x, y, z, w, h, facing, PAL.yellow, PAL.black) end
function P.restrictedSign(r, text, x, y, z, w, h, facing) return P.sign(r, text, x, y, z, w, h, facing, PAL.red, PAL.offwhite) end
function P.infoSign(r, text, x, y, z, w, h, facing) return P.sign(r, text, x, y, z, w, h, facing, PAL.blueDark, PAL.offwhite) end
function P.greenSign(r, text, x, y, z, w, h, facing) return P.sign(r, text, x, y, z, w, h, facing, PAL.green, PAL.offwhite) end

function P.poster(r, x, y, z, facing, variant)
	local V = {
		{ "REPORT ALL ANOMALIES\nTO YOUR SUPERVISOR", C(206, 198, 170), C(40, 40, 40) },
		{ "WASH HANDS\nBEFORE LEAVING SECTOR", C(168, 196, 206), C(24, 40, 56) },
		{ "NO FOOD OR DRINK\nIN LABORATORIES", C(214, 160, 70), C(40, 24, 8) },
		{ "BADGE UP.\nBADGE OUT.", C(120, 150, 130), C(12, 30, 16) },
		{ "DAYS SINCE LAST\nINCIDENT:  0", C(190, 60, 52), C(250, 240, 230) },
		{ "SAFETY IS\nEVERYONE'S JOB", C(210, 190, 90), C(30, 30, 30) },
	}
	local v = V[variant or rng:NextInteger(1, #V)]
	local p = P.sign(r, v[1], x, y, z, 3.2, 4.4, facing, v[2], v[3], { font = Enum.Font.GothamMedium })
	return p
end

-- ----- storage ---------------------------------------------------------
function P.crate(r, x, y0, z, w, h, d, facing, kind)
	kind = kind or "wood"
	local par = r.props
	local cf = frame(x, y0, z, facing)
	local mat, col = M.WoodPlanks, jitter(PAL.wood, 0.12)
	if kind == "metal" then mat, col = M.Metal, jitter(C(70, 82, 74), 0.15) end
	if kind == "bio" then mat, col = M.Plastic, jitter(C(176, 146, 40), 0.1) end
	if kind == "cardboard" then mat, col = M.Cardboard, jitter(PAL.cardboard, 0.1) end
	lp(par, "Crate", cf, 0, h / 2, 0, w, h, d, mat, col)
	if kind == "wood" or kind == "metal" then
		local band = kind == "wood" and shade(col, 0.62) or PAL.steelLight
		lp(par, "CrateBand", cf, 0, h / 2, -d * 0.3, w + 0.1, h + 0.1, 0.35, mat, band, DECO)
		lp(par, "CrateBand", cf, 0, h / 2, d * 0.3, w + 0.1, h + 0.1, 0.35, mat, band, DECO)
	end
	local lab = kind == "bio" and PAL.black or (kind == "metal" and PAL.yellow or PAL.paper)
	lp(par, "CrateLabel", cf, 0, h * 0.62, d / 2 + 0.03, math.min(w * 0.45, 1.8), h * 0.22, 0.05, M.SmoothPlastic, lab, DECO)
end
function P.pallet(r, x, z, facing)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "PalletDeck", cf, 0, 0.55, 0, 4, 0.2, 4, M.WoodPlanks, jitter(PAL.wood, 0.1))
	for i = -1, 1 do lp(par, "PalletRunner", cf, i * 1.7, 0.22, 0, 0.5, 0.44, 4, M.WoodPlanks, shade(PAL.wood, 0.8)) end
end
function P.barrel(r, x, z, color, y0)
	y0 = y0 or 0
	local par = r.props
	local col = color or pick({ PAL.rust, PAL.blueDark, C(70, 84, 70), PAL.steelDark })
	cylY(par, "Barrel", x, y0, y0 + 3.4, z, 2.2, M.Metal, col)
	cylY(par, "BarrelRing", x, y0 + 1.0, y0 + 1.25, z, 2.32, M.Metal, shade(col, 0.7), DECO)
	cylY(par, "BarrelRing", x, y0 + 2.2, y0 + 2.45, z, 2.32, M.Metal, shade(col, 0.7), DECO)
end
-- shelving run along local +X.  tiers x bays; stocked with random boxes
function P.shelf(r, x, z, facing, bays, tiers, stock)
	local par, cf = r.props, frame(x, 0, z, facing)
	local bay, spacing = 6, 3.3
	local len, H = bays * bay, tiers * spacing + 0.6
	for i = 0, bays do
		for _, dz in ipairs({ -0.95, 0.95 }) do
			lp(par, "Upright", cf, i * bay, H / 2, dz, 0.3, H, 0.3, M.Metal, PAL.blue)
		end
	end
	for t = 0, tiers - 1 do
		local y = 0.35 + t * spacing
		lp(par, "ShelfPlank", cf, len / 2, y, 0, len, 0.2, 2.2, M.Metal, PAL.steelDark)
		for b = 0, bays - 1 do
			if chance(stock or 0.8) or (stock or 0.8) >= 1 then
				local n = rng:NextInteger(1, 3)
				for k = 1, n do
					local bw, bh, bd = rand(1.2, 2.1), rand(1.2, 2.4), rand(1.1, 1.7)
					local col = pick({ PAL.cardboard, jitter(PAL.cardboard, 0.2), C(70, 78, 70), C(150, 150, 140), jitter(PAL.wood, 0.1) })
					lp(par, "StockBox", cf, b * bay + (k - 0.5) * (bay / n), y + 0.1 + bh / 2, rand(-0.2, 0.2), bw, bh, bd,
						col == PAL.cardboard and M.Cardboard or M.SmoothPlastic, col, DECO)
				end
			end
		end
	end
end
function P.lockers(r, x, z, facing, n, h)
	h = h or 6.4
	local par, cf = r.props, frame(x, 0, z, facing)
	local col = jitter(C(62, 74, 66), 0.12)
	for i = 0, n - 1 do
		local c = jitter(col, 0.08)
		lp(par, "Locker", cf, i * 2 + 1, h / 2, 0.9, 1.95, h, 1.8, M.Metal, shade(c, 0.7))
		lp(par, "LockerDoor", cf, i * 2 + 1, h / 2, 1.82, 1.75, h - 0.3, 0.1, M.CorrodedMetal, c, DECO)
		lp(par, "LockerVent", cf, i * 2 + 1, h - 0.9, 1.9, 1.2, 0.5, 0.05, M.Metal, PAL.black, DECO)
	end
end
function P.cabinet(r, x, z, facing, w, h, d, color)
	local par, cf = r.props, frame(x, 0, z, facing)
	local c = color or jitter(PAL.steel, 0.1)
	lp(par, "Cabinet", cf, 0, h / 2, 0, w, h, d, M.Metal, c)
	lp(par, "CabinetDoorSeam", cf, 0, h / 2, d / 2 + 0.02, 0.1, h - 0.4, 0.05, M.Metal, PAL.black, DECO)
	lp(par, "CabinetHandle", cf, w * 0.12, h * 0.5, d / 2 + 0.1, 0.15, 0.9, 0.15, M.Metal, PAL.steelLight, DECO)
	lp(par, "CabinetHandle", cf, -w * 0.12, h * 0.5, d / 2 + 0.1, 0.15, 0.9, 0.15, M.Metal, PAL.steelLight, DECO)
end
function P.jersey(r, x, z, facing, len)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "BarrierBase", cf, 0, 0.7, 0, len, 1.4, 2.2, M.Concrete, jitter(PAL.concrete, 0.1))
	lp(par, "BarrierTop", cf, 0, 2.1, 0, len, 1.4, 1.0, M.Concrete, jitter(PAL.concrete, 0.1))
end

-- ----- furniture -------------------------------------------------------
function P.desk(r, x, z, facing, w, d, color)
	local par, cf = r.props, frame(x, 0, z, facing)
	local c = color or jitter(PAL.steel, 0.1)
	lp(par, "DeskTop", cf, 0, 3.0, 0, w, 0.3, d, M.Metal, c)
	lp(par, "DeskSide", cf, -w / 2 + 0.2, 1.5, 0, 0.4, 3, d - 0.3, M.Metal, shade(c, 0.8))
	lp(par, "DeskSide", cf, w / 2 - 0.2, 1.5, 0, 0.4, 3, d - 0.3, M.Metal, shade(c, 0.8))
	lp(par, "DeskPanel", cf, 0, 1.6, -d / 2 + 0.3, w - 0.6, 2.6, 0.25, M.Metal, shade(c, 0.7))
end
function P.chair(r, x, z, facing, tipped)
	local par = r.props
	local cf = frame(x, 0, z, facing)
	if tipped then cf = CFrame.new(x, 1.0, z) * CFrame.Angles(0, yawOf(facing), 0) * CFrame.Angles(0, 0, math.rad(rand(80, 95))) end
	lp(par, "ChairSeat", cf, 0, 1.9, 0, 1.8, 0.28, 1.8, M.Fabric, PAL.blueDark)
	lp(par, "ChairBack", cf, 0, 3.2, -0.8, 1.7, 2.2, 0.25, M.Fabric, PAL.blueDark)
	lp(par, "ChairPost", cf, 0, 1.0, 0, 0.3, 1.8, 0.3, M.Metal, PAL.steelDark)
	lp(par, "ChairBase", cf, 0, 0.2, 0, 1.8, 0.2, 0.3, M.Metal, PAL.steelDark, DECO)
	lp(par, "ChairBase", cf, 0, 0.2, 0, 0.3, 0.2, 1.8, M.Metal, PAL.steelDark, DECO)
end
function P.bench(r, x, z, facing, len, tipped)
	local par = r.props
	local cf = frame(x, 0, z, facing)
	if tipped then cf = CFrame.new(x, 0.9, z) * CFrame.Angles(0, yawOf(facing), 0) * CFrame.Angles(math.rad(88), 0, 0) end
	lp(par, "BenchSeat", cf, len / 2, 1.7, 0, len, 0.3, 1.6, M.Metal, PAL.steelDark)
	lp(par, "BenchCushion", cf, len / 2, 1.95, 0, len - 0.4, 0.25, 1.3, M.Fabric, PAL.blueDark, DECO)
	lp(par, "BenchLeg", cf, 0.4, 0.85, 0, 0.3, 1.7, 1.4, M.Metal, PAL.steelDark)
	lp(par, "BenchLeg", cf, len - 0.4, 0.85, 0, 0.3, 1.7, 1.4, M.Metal, PAL.steelDark)
end
function P.monitor(r, x, y, z, facing, state, scrCol)
	local par, cf = r.props, frame(x, y, z, facing)
	lp(par, "MonitorBezel", cf, 0, 0.9, 0, 2.3, 1.7, 0.3, M.SmoothPlastic, PAL.black, DECO)
	lp(par, "MonitorStand", cf, 0, 0.15, -0.1, 0.5, 0.3, 0.5, M.SmoothPlastic, PAL.black, DECO)
	if state == "on" then
		local col = scrCol or pick({ PAL.cyan, PAL.green, C(90, 160, 220) })
		local s = lp(par, "MonitorScreen", cf, 0, 0.95, 0.17, 2.0, 1.4, 0.05, M.Neon, shade(col, 0.55), DECO)
		tag(s, "Screen")
	elseif state == "broken" then
		lp(par, "MonitorScreen", cf, 0, 0.95, 0.17, 2.0, 1.4, 0.05, M.Glass, C(10, 12, 14), { deco = true, refl = 0.2 })
		lp(par, "MonitorCrack", cf, 0, 0.95, 0.2, 0.08, 1.7, 0.03, M.SmoothPlastic, C(150, 160, 160), DECO)
	else
		lp(par, "MonitorScreen", cf, 0, 0.95, 0.17, 2.0, 1.4, 0.05, M.Glass, C(14, 18, 20), { deco = true, refl = 0.15 })
	end
end
function P.console(r, x, z, facing, w, states)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "ConsoleBody", cf, w / 2, 1.5, 0, w, 3.0, 2.6, M.Metal, PAL.steelDark)
	lp(par, "ConsoleTop", cf, w / 2, 3.05, 0, w + 0.2, 0.2, 2.8, M.Metal, PAL.steel)
	lp(par, "Keyboard", cf, w / 2, 3.25, 0.6, math.min(w - 1, 2.6), 0.15, 0.8, M.SmoothPlastic, C(40, 42, 44), DECO)
	local n = math.max(1, math.floor(w / 3))
	for i = 1, n do
		local wp = cf * Vector3.new((i - 0.5) * (w / n), 3.15, -0.4)
		P.monitor(r, wp.X, wp.Y, wp.Z, facing, states and states[i] or "on")
	end
end
function P.cabinetMed(r, x, y, z, facing, w, h)
	local par, cf = r.props, frame(x, y, z, facing)
	lp(par, "WallCabinet", cf, 0, h / 2, 0.6, w, h, 1.2, M.Metal, PAL.offwhite)
	lp(par, "WallCabinetGlass", cf, 0, h / 2, 1.22, w - 0.4, h - 0.4, 0.05, M.Glass, C(160, 200, 200), { deco = true, tr = 0.6 })
	lp(par, "MedCross", cf, 0, h - 0.5, 1.26, 0.8, 0.2, 0.04, M.SmoothPlastic, PAL.green, DECO)
	lp(par, "MedCross", cf, 0, h - 0.5, 1.26, 0.2, 0.8, 0.04, M.SmoothPlastic, PAL.green, DECO)
end

-- ----- laboratory ------------------------------------------------------
function P.labTable(r, x, z, facing, len, theme)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "LabBase", cf, len / 2, 1.4, 0, len - 0.4, 2.8, 2.2, M.Metal, PAL.offwhite)
	lp(par, "LabTop", cf, len / 2, 2.95, 0, len, 0.22, 2.7, M.SmoothPlastic, C(34, 44, 48))
	lp(par, "LabKick", cf, len / 2, 0.2, 0, len - 0.2, 0.4, 2.3, M.Metal, PAL.steelDark, DECO)
	local top = 3.06
	if theme == "chem" then
		for i = 1, math.max(2, math.floor(len / 3)) do
			local fx = i * (len / (math.floor(len / 3) + 1))
			local col = pick({ C(120, 210, 120), C(220, 200, 90), C(120, 190, 230) })
			lp(par, "Flask", cf, fx, top + 0.5, rand(-0.5, 0.5), 0.7, 1.0, 0.7, M.Glass, col, { deco = true, tr = 0.35 })
		end
		lp(par, "Burner", cf, len * 0.8, top + 0.4, 0, 0.6, 0.8, 0.6, M.Metal, PAL.steelDark, DECO)
	elseif theme == "bio" then
		lp(par, "MicroscopeBase", cf, len * 0.3, top + 0.1, 0, 1.2, 0.2, 1.4, M.Metal, PAL.black, DECO)
		lp(par, "MicroscopeArm", cf, len * 0.3, top + 0.9, -0.3, 0.3, 1.6, 0.3, M.Metal, PAL.black, DECO)
		lp(par, "MicroscopeTube", cf, len * 0.3, top + 1.6, 0, 0.35, 0.35, 1.0, M.Metal, PAL.steelDark, DECO)
		lp(par, "PetriTray", cf, len * 0.65, top + 0.1, 0, 1.8, 0.15, 1.2, M.SmoothPlastic, PAL.offwhite, DECO)
	else
		lp(par, "Instrument", cf, len * 0.3, top + 0.6, 0, 1.8, 1.2, 1.4, M.Metal, PAL.steelDark, DECO)
		lp(par, "InstrumentScreen", cf, len * 0.3, top + 0.8, 0.72, 1.2, 0.5, 0.05, M.Neon, shade(PAL.cyan, 0.5), DECO)
		lp(par, "Instrument", cf, len * 0.7, top + 0.5, 0, 1.6, 1.0, 1.4, M.Metal, shade(PAL.steelDark, 1.3), DECO)
	end
end
function P.fumeHood(r, x, z, facing)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "HoodBase", cf, 0, 1.5, 0, 5, 3, 2.6, M.Metal, PAL.offwhite)
	lp(par, "HoodTop", cf, 0, 3.1, 0, 5.2, 0.2, 2.8, M.SmoothPlastic, C(34, 44, 48))
	lp(par, "HoodBack", cf, 0, 5.6, -1.1, 5, 5, 0.3, M.Metal, PAL.offwhite)
	lp(par, "HoodSash", cf, 0, 5.4, 1.2, 4.6, 3.6, 0.1, M.Glass, C(170, 210, 210), { deco = true, tr = 0.7 })
	lp(par, "HoodCanopy", cf, 0, 8.0, 0, 5.2, 0.5, 2.8, M.Metal, PAL.steel)
	lp(par, "HoodDuct", cf, 0, 10.6, -0.4, 1.4, 5, 1.4, M.Metal, PAL.steelLight, DECO)
end
-- containment tank. state: full | cracked | empty ; specimen adds a dark shape inside
function P.tank(r, x, z, diam, h, liquid, state, specimen)
	local par = r.props
	state = state or "full"
	cylY(par, "TankBase", x, 0, 1.0, z, diam + 1.2, M.Metal, PAL.steelDark)
	cylY(par, "TankCap", x, h, h + 0.9, z, diam + 1.0, M.Metal, PAL.steelDark)
	if state ~= "cracked" then
		cylY(par, "TankGlass", x, 1.0, h, z, diam, M.Glass, C(190, 220, 220), { tr = 0.72, refl = 0.1, shadow = false })
	else
		cylY(par, "TankGlassLow", x, 1.0, h * 0.5, z, diam, M.Glass, C(190, 220, 220), { tr = 0.72, refl = 0.1, shadow = false })
		for i = 1, 3 do
			lp(par, "GlassShard", frame(x + math.cos(i * 2.1) * diam * 0.5, h * 0.45 + i * 0.4, z + math.sin(i * 2.1) * diam * 0.5, rand(0, 6)),
				0, 0, 0, 0.1, rand(1.5, 3), rand(0.6, 1.3), M.Glass, C(190, 220, 220), { deco = true, tr = 0.6 })
		end
	end
	if state == "full" then
		cylY(par, "TankLiquid", x, 1.2, h - 0.6, z, diam - 0.3, M.Neon, liquid, { deco = true, tr = 0.55 })
	elseif state == "cracked" then
		cylY(par, "TankLiquid", x, 1.2, h * 0.28, z, diam - 0.3, M.Neon, liquid, { deco = true, tr = 0.5 })
		disc(par, "TankSpill", x, 0.06, z, diam * 2.4, 0.05, M.Neon, shade(liquid, 0.5), { deco = true, tr = 0.6 })
	end
	if specimen then
		local sy = state == "full" and h * 0.5 or 1.4
		cylY(par, "Specimen", x, sy - 1.8, sy + 1.8, z, diam * 0.28, M.SmoothPlastic, C(34, 30, 28), { deco = true })
		mk(par, "SpecimenHead", Vector3.new(diam * 0.4, diam * 0.46, diam * 0.4), CFrame.new(x, sy + 2.1, z), M.SmoothPlastic, C(34, 30, 28), { deco = true, shape = SHAPE_BALL })
	end
	cylY(par, "TankPipe", x + diam * 0.35, h + 0.9, r.h, z, 0.5, M.Metal, PAL.steel, DECO)
end

-- ----- medical ---------------------------------------------------------
function P.bed(r, x, z, facing, state)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "BedFrame", cf, 0, 1.9, 0, 3.0, 0.3, 6.8, M.Metal, PAL.steelLight)
	lp(par, "Mattress", cf, 0, 2.3, 0.2, 2.8, 0.5, 6.0, M.Fabric, state == "stained" and C(170, 160, 150) or PAL.offwhite)
	lp(par, "Pillow", cf, 0, 2.7, -2.4, 2.0, 0.4, 1.2, M.Fabric, PAL.offwhite, DECO)
	lp(par, "BedHead", cf, 0, 3.2, -3.4, 3.0, 2.4, 0.3, M.Metal, PAL.steelLight)
	lp(par, "BedFoot", cf, 0, 2.6, 3.4, 3.0, 1.4, 0.3, M.Metal, PAL.steelLight)
	for _, sx in ipairs({ -1.55, 1.55 }) do
		lp(par, "BedRail", cf, sx, 2.9, 0, 0.15, 0.15, 5.0, M.Metal, PAL.steelLight, DECO)
		lp(par, "BedLeg", cf, sx, 0.95, -2.8, 0.3, 1.9, 0.3, M.Metal, PAL.steelDark)
		lp(par, "BedLeg", cf, sx, 0.95, 2.8, 0.3, 1.9, 0.3, M.Metal, PAL.steelDark)
	end
	if state == "stained" then
		lp(par, "BedStain", cf, 0.3, 2.58, 0.4, 1.6, 0.04, 2.2, M.SmoothPlastic, PAL.blood, { deco = true, tr = 0.15 })
	elseif state == "straps" then
		for _, oz in ipairs({ -1.2, 0.6, 2.2 }) do
			lp(par, "Strap", cf, 0, 2.62, oz, 3.2, 0.12, 0.35, M.Fabric, C(40, 32, 26), DECO)
		end
	end
end
function P.ivStand(r, x, z)
	local par = r.props
	cylY(par, "IVPole", x, 0.3, 6.2, z, 0.25, M.Metal, PAL.steelLight, DECO)
	cb(par, "IVBase", x, 0.15, z, 2.0, 0.3, 0.3, 0, M.Metal, PAL.steelDark, DECO)
	cb(par, "IVBase", x, 0.15, z, 0.3, 0.3, 2.0, 0, M.Metal, PAL.steelDark, DECO)
	cb(par, "IVBag", x + 0.5, 5.4, z, 0.5, 1.1, 0.25, 0, M.Glass, C(180, 210, 230), { deco = true, tr = 0.45 })
end
function P.curtain(r, x, y0, z, facing, len, h)
	local par, cf = r.props, frame(x, y0, z, facing)
	lp(par, "CurtainTrack", cf, len / 2, h + 0.15, 0, len, 0.2, 0.3, M.Metal, PAL.steelLight, DECO)
	lp(par, "Curtain", cf, len / 2, h / 2 - 0.1, 0, len, h - 0.6, 0.12, M.Fabric, C(150, 176, 168), { deco = true, tr = 0.12 })
end
function P.gurney(r, x, z, facing, tipped)
	local par = r.props
	local cf = frame(x, 0, z, facing)
	if tipped then cf = CFrame.new(x, 1.2, z) * CFrame.Angles(0, yawOf(facing), 0) * CFrame.Angles(0, 0, math.rad(84)) end
	lp(par, "GurneyTop", cf, 0, 2.5, 0, 2.6, 0.3, 6.4, M.Metal, PAL.steelLight)
	lp(par, "GurneyPad", cf, 0, 2.85, 0, 2.4, 0.4, 6.0, M.Fabric, C(70, 100, 110), DECO)
	for _, sx in ipairs({ -1.0, 1.0 }) do
		lp(par, "GurneyLeg", cf, sx, 1.2, -2.4, 0.25, 2.4, 0.25, M.Metal, PAL.steelDark)
		lp(par, "GurneyLeg", cf, sx, 1.2, 2.4, 0.25, 2.4, 0.25, M.Metal, PAL.steelDark)
	end
end

-- ----- industrial ------------------------------------------------------
function P.generator(r, x, z, facing, w, d, h)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "GenBase", cf, 0, 0.5, 0, w + 0.6, 1.0, d + 0.6, M.Concrete, PAL.concreteDark)
	lp(par, "GenBody", cf, 0, 1.0 + h / 2, 0, w, h, d, M.Metal, jitter(C(70, 84, 70), 0.1))
	for i = -2, 2 do
		lp(par, "GenRib", cf, i * (w / 5.5), 1.0 + h / 2, d / 2 + 0.1, 0.4, h - 0.6, 0.3, M.Metal, PAL.steelDark, DECO)
	end
	lp(par, "GenPanel", cf, 0, 1.0 + h * 0.62, d / 2 + 0.1, w * 0.4, h * 0.3, 0.2, M.Metal, PAL.black)
	for i = 1, 3 do
		lp(par, "GenLED", cf, -w * 0.12 + i * 0.7, 1.0 + h * 0.66, d / 2 + 0.25, 0.3, 0.3, 0.1, M.Neon, pick({ PAL.green, PAL.orange, PAL.red }), DECO)
	end
	cylY(par, "GenExhaust", x + w * 0.3, 1.0 + h, r.h - 0.5, z - d * 0.2, 1.1, M.CorrodedMetal, PAL.rustDark, DECO)
	local hz = lp(par, "GenHazard", cf, 0, 1.4, d / 2 + 0.31, w, 0.9, 0.05, M.SmoothPlastic, PAL.yellow, DECO)
	hazardFace(hz, NID.Back)
end
-- the maintenance landmark: reactor core with glowing band
function P.reactor(r, x, z, diam, h)
	local par = r.props
	cylY(par, "ReactorPlinth", x, 0, 1.0, z, diam + 6, M.Concrete, PAL.concreteDark)
	cylY(par, "ReactorShell", x, 1.0, h, z, diam, M.Metal, jitter(C(78, 88, 82), 0.06))
	for i, yy in ipairs({ 4, 8.5, 13 }) do
		if yy < h - 1 then cylY(par, "ReactorRing", x, yy, yy + 0.6, z, diam + 0.6, M.CorrodedMetal, PAL.rustDark, DECO) end
	end
	local band = cylY(par, "ReactorCoreBand", x, 6.0, 7.4, z, diam + 0.25, M.Neon, C(255, 130, 40), { deco = true, tr = 0.25 })
	addLight("point", band, C(255, 140, 60), 2.2, 30, { shadows = false })
	tag(band, "PulseLight")
	band:SetAttribute("Speed", 0.7)
	cylY(par, "ReactorCap", x, h, h + 0.8, z, diam * 0.7, M.Metal, PAL.steelDark)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		cylY(par, "CoolantPipe", x + math.cos(a) * diam * 0.36, h + 0.8, r.h, z + math.sin(a) * diam * 0.36, 0.9, M.Metal, PAL.steel, DECO)
	end
end

function P.pipeRun(r, axis, a0, a1, f, y, d, color, o)
	o = o or {}
	local par = r.props
	local col = color or PAL.rust
	local p
	if axis == "x" then p = cylX(par, "Pipe", a0, a1, y, f, d, M.Metal, col, DECO)
	else p = cylZ(par, "Pipe", a0, a1, f, y, d, M.Metal, col, DECO) end
	local a = a0 + 3
	while a < a1 do
		if axis == "x" then
			cb(par, "PipeHanger", a, (y + r.h) / 2, f, 0.3, r.h - y, d + 0.5, 0, M.Metal, PAL.steelDark, DECO)
		else
			cb(par, "PipeHanger", f, (y + r.h) / 2, a, d + 0.5, r.h - y, 0.3, 0, M.Metal, PAL.steelDark, DECO)
		end
		a += 8
	end
	if o.valves then
		local a2 = a0 + (a1 - a0) * 0.45
		if axis == "x" then
			cylX(par, "Flange", a2 - 0.3, a2 + 0.3, y, f, d + 0.5, M.Metal, PAL.steelDark, DECO)
			cylY(par, "ValveStem", a2, y, y + d / 2 + 0.9, f, 0.2, M.Metal, PAL.steelDark, DECO)
			cylY(par, "ValveWheel", a2, y + d / 2 + 0.9, y + d / 2 + 1.0, f, 1.1, M.Metal, PAL.red, DECO)
		else
			cylZ(par, "Flange", a2 - 0.3, a2 + 0.3, f, y, d + 0.5, M.Metal, PAL.steelDark, DECO)
			cylY(par, "ValveStem", f, y, y + d / 2 + 0.9, a2, 0.2, M.Metal, PAL.steelDark, DECO)
			cylY(par, "ValveWheel", f, y + d / 2 + 0.9, y + d / 2 + 1.0, a2, 1.1, M.Metal, PAL.red, DECO)
		end
	end
	return p
end
function P.cableTray(r, axis, a0, a1, f, y, w)
	local par = r.props
	if axis == "x" then
		bx(par, "TrayBed", a0, a1, y, y + 0.15, f - w / 2, f + w / 2, M.Metal, PAL.steelDark, DECO)
		bx(par, "TrayRail", a0, a1, y, y + 0.5, f - w / 2, f - w / 2 + 0.15, M.Metal, PAL.steelDark, DECO)
		bx(par, "TrayRail", a0, a1, y, y + 0.5, f + w / 2 - 0.15, f + w / 2, M.Metal, PAL.steelDark, DECO)
		cylX(par, "Cable", a0, a1, y + 0.3, f - w * 0.2, 0.22, M.Rubber, PAL.black, DECO)
		cylX(par, "Cable", a0, a1, y + 0.3, f + w * 0.1, 0.18, M.Rubber, PAL.yellow, DECO)
	else
		bx(par, "TrayBed", f - w / 2, f + w / 2, y, y + 0.15, a0, a1, M.Metal, PAL.steelDark, DECO)
		bx(par, "TrayRail", f - w / 2, f - w / 2 + 0.15, y, y + 0.5, a0, a1, M.Metal, PAL.steelDark, DECO)
		bx(par, "TrayRail", f + w / 2 - 0.15, f + w / 2, y, y + 0.5, a0, a1, M.Metal, PAL.steelDark, DECO)
		cylZ(par, "Cable", a0, a1, f - w * 0.2, y + 0.3, 0.22, M.Rubber, PAL.black, DECO)
		cylZ(par, "Cable", a0, a1, f + w * 0.1, y + 0.3, 0.18, M.Rubber, PAL.yellow, DECO)
	end
	local a = a0 + 2
	while a < a1 do
		if axis == "x" then bx(par, "TrayHanger", a - 0.1, a + 0.1, y, r.h, f - 0.1, f + 0.1, M.Metal, PAL.steelDark, DECO)
		else bx(par, "TrayHanger", f - 0.1, f + 0.1, y, r.h, a - 0.1, a + 0.1, M.Metal, PAL.steelDark, DECO) end
		a += 9
	end
end
function P.duct(r, axis, a0, a1, f, y, w, h, color)
	local par = r.props
	local col = color or PAL.steelLight
	if axis == "x" then
		bx(par, "Duct", a0, a1, y, y + h, f - w / 2, f + w / 2, M.Metal, col, DECO)
		local a = a0 + 4
		while a < a1 do bx(par, "DuctSeam", a - 0.15, a + 0.15, y - 0.1, y + h + 0.1, f - w / 2 - 0.1, f + w / 2 + 0.1, M.Metal, shade(col, 0.6), DECO) a += 6 end
	else
		bx(par, "Duct", f - w / 2, f + w / 2, y, y + h, a0, a1, M.Metal, col, DECO)
		local a = a0 + 4
		while a < a1 do bx(par, "DuctSeam", f - w / 2 - 0.1, f + w / 2 + 0.1, y - 0.1, y + h + 0.1, a - 0.15, a + 0.15, M.Metal, shade(col, 0.6), DECO) a += 6 end
	end
end
function P.vent(r, x, y, z, facing, w, h)
	local par, cf = r.props, frame(x, y, z, facing)
	lp(par, "VentFrame", cf, 0, h / 2, 0.15, w + 0.3, h + 0.3, 0.3, M.Metal, PAL.steelDark, DECO)
	lp(par, "VentBack", cf, 0, h / 2, 0.32, w, h, 0.05, M.SmoothPlastic, PAL.black, DECO)
	for i = 1, 4 do lp(par, "VentSlat", cf, 0, h * i / 5, 0.38, w, 0.12, 0.12, M.Metal, PAL.steel, DECO) end
end
-- ceiling/wall fan. blades spin on clients (tag Fan). facing = direction the fan blows
function P.fan(r, x, y, z, facing, d)
	local par = r.props
	local yaw = yawOf(facing)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	mk(par, "FanHousing", Vector3.new(d + 0.6, d + 0.6, 0.6), cf * CFrame.new(0, 0, 0.3), M.Metal, PAL.steelDark, DECO)
	local m = Instance.new("Model")
	m.Name = "FanBlades"
	local hub = mk(m, "Hub", Vector3.new(0.7, 0.7, 0.4), cf * CFrame.new(0, 0, 0.7), M.Metal, PAL.black, DECO)
	mk(m, "Blade", Vector3.new(d * 0.9, 0.6, 0.12), cf * CFrame.new(0, 0, 0.7), M.Metal, PAL.steel, DECO)
	mk(m, "Blade", Vector3.new(0.6, d * 0.9, 0.12), cf * CFrame.new(0, 0, 0.7), M.Metal, PAL.steel, DECO)
	m.PrimaryPart = hub
	m.Parent = par
	tag(m, "Fan")
	m:SetAttribute("Speed", rand(2.5, 4.5))
end
function P.cctv(r, x, y, z, facing, state)
	local par = r.props
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yawOf(facing), 0)
	lp(par, "CamBracket", cf, 0, 0, 0.3, 0.3, 0.3, 0.6, M.Metal, PAL.steelDark, DECO)
	local tilt = cf * CFrame.new(0, -0.3, 1.0) * CFrame.Angles(math.rad(state == "dead" and 40 or 18), 0, state == "dead" and math.rad(14) or 0)
	local body = mk(par, "CCTV", Vector3.new(0.9, 0.8, 2.0), tilt, M.Metal, PAL.offwhite, DECO)
	mk(par, "CCTVLens", Vector3.new(0.6, 0.6, 0.3), tilt * CFrame.new(0, 0, 1.1), M.Glass, C(10, 12, 14), { deco = true, refl = 0.3 })
	if state ~= "dead" then
		local led = mk(par, "CCTVLed", Vector3.new(0.2, 0.2, 0.1), tilt * CFrame.new(0.28, 0.3, 0.9), M.Neon, C(255, 40, 30), DECO)
		tag(led, "PulseLight")
		led:SetAttribute("Speed", 1.4)
	end
	tag(body, "Camera")
end
function P.panel(r, x, y, z, facing, w, h, state)
	local par, cf = r.props, frame(x, y, z, facing)
	lp(par, "ElecPanel", cf, 0, h / 2, 0.25, w, h, 0.5, M.Metal, jitter(PAL.steel, 0.1), DECO)
	lp(par, "PanelDoor", cf, 0, h / 2, 0.52, w - 0.3, h - 0.3, 0.06, M.Metal, shade(PAL.steel, 0.85), DECO)
	for i = 1, 3 do
		lp(par, "PanelLED", cf, -w / 2 + 0.5 + i * 0.45, h - 0.55, 0.58, 0.22, 0.22, 0.06, M.Neon,
			(state == "dead" and PAL.redDark) or pick({ PAL.green, PAL.green, PAL.orange }), DECO)
	end
	P.hazardSign(r, "HIGH VOLTAGE", x, y + h + 0.9, z, 2.4, 1.0, facing)
	if state == "open" then
		local open = cf * CFrame.new(-w / 2, 0, 0.55) * CFrame.Angles(0, math.rad(-70), 0)
		mk(par, "PanelDoorOpen", Vector3.new(w - 0.3, h - 0.3, 0.06), open * CFrame.new((w - 0.3) / 2, h / 2, 0), M.Metal, shade(PAL.steel, 0.85), DECO)
		for i = 1, 3 do
			lp(par, "Wire", cf, -0.8 + i * 0.7, h * 0.4, 0.62, 0.12, rand(1, 2.5), 0.12, M.Rubber, pick({ PAL.red, PAL.yellow, PAL.black, PAL.cyan }), DECO)
		end
		emitter(r, x, y + h * 0.4, z + 0.6, "spark", { every = rand(4, 9), dir = NID.Front })
	end
end
function P.extinguisher(r, x, z, facing)
	local par = r.props
	local cf = frame(x, 0, z, facing)
	cylY(par, "Extinguisher", x, 1.6, 3.9, z, 0.8, M.Metal, PAL.red, DECO)
	lp(par, "ExtHead", cf, 0, 4.1, 0, 0.5, 0.4, 0.5, M.Metal, PAL.black, DECO)
	lp(par, "ExtBracket", cf, 0, 3.0, -0.45, 0.9, 0.3, 0.2, M.Metal, PAL.steelDark, DECO)
	P.sign(r, "FIRE", x, 5.2, z, 1.4, 0.7, facing, PAL.red, PAL.offwhite)
end
function P.exitSign(r, x, y, z, facing, text)
	local par = r.props
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yawOf(facing), 0)
	local p = mk(par, "ExitSign", Vector3.new(3.2, 1.2, 0.3), cf * CFrame.new(0, 0, 0.15), M.Neon, shade(PAL.green, 0.8), DECO)
	surfText(p, NID.Back, text or "EXIT", C(10, 30, 14), { font = Enum.Font.GothamBlack, glow = true })
	addLight("point", p, PAL.green, 0.5, 9, { shadows = false })
end

-- ----- story / mess ----------------------------------------------------
function P.blood(r, x, z, size, yaw)
	local par = r.story
	for i = 1, 3 do
		local s = size * rand(0.5, 1.0)
		cb(par, "Blood", x + rand(-size, size) * 0.3, 0.05 + i * 0.002, z + rand(-size, size) * 0.3, s, 0.04, s * rand(0.5, 1.0),
			(yaw or 0) + rand(-1, 1), M.SmoothPlastic, jitter(PAL.blood, 0.25), { deco = true, refl = 0.12 })
	end
end
function P.bloodWall(r, x, y, z, facing, h)
	local par, cf = r.story, frame(x, y, z, facing)
	lp(par, "BloodSmear", cf, 0, -h / 2, 0.05, rand(0.8, 1.6), h, 0.04, M.SmoothPlastic, PAL.blood, { deco = true, tr = 0.1 })
	lp(par, "BloodSmear", cf, rand(-0.6, 0.6), -h * 0.4, 0.05, 0.35, h * 0.8, 0.04, M.SmoothPlastic, shade(PAL.blood, 0.8), { deco = true, tr = 0.1 })
end
function P.drag(r, x0, z0, x1, z1)
	local n = math.floor(math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2) / 2.5)
	local yaw = math.atan2(x1 - x0, z1 - z0)
	for i = 0, n do
		local t = i / math.max(1, n)
		cb(r.story, "DragMark", x0 + (x1 - x0) * t + rand(-0.3, 0.3), 0.05, z0 + (z1 - z0) * t + rand(-0.3, 0.3),
			rand(0.9, 1.5) * (1.1 - t * 0.6), 0.04, 2.4, yaw, M.SmoothPlastic, jitter(PAL.blood, 0.2), { deco = true, refl = 0.1 })
	end
end
function P.papers(r, x, z, radius, n)
	n = math.floor(n * CFG.DETAIL)
	for _ = 1, n do
		local a, d = rand(0, 6.28), rand(0, radius)
		cb(r.story, "Paper", x + math.cos(a) * d, 0.06 + rand(0, 0.02), z + math.sin(a) * d, rand(0.9, 1.2), 0.03, rand(1.2, 1.6), rand(0, 6.28),
			M.SmoothPlastic, jitter(PAL.paper, 0.12), DECO)
	end
end
function P.rubble(r, x, z, radius, n, big)
	n = math.floor(n * math.max(CFG.DETAIL, 0.3))
	for _ = 1, n do
		local a, d = rand(0, 6.28), rand(0, radius)
		local s = rand(0.4, big and 2.2 or 1.2)
		local px, pz = x + math.cos(a) * d, z + math.sin(a) * d
		mk(r.story, "Rubble", Vector3.new(s, s * rand(0.5, 1.0), s * rand(0.6, 1.2)),
			CFrame.new(px, s * 0.25, pz) * CFrame.Angles(rand(-0.4, 0.4), rand(0, 6.28), rand(-0.4, 0.4)),
			M.Concrete, jitter(PAL.concreteDark, 0.25), { cc = s > 1.5, shadow = false, deco = s <= 1.5 })
	end
end
function P.puddle(r, x, z, d)
	disc(r.story, "Puddle", x, 0.05, z, d, 0.05, M.SmoothPlastic, C(28, 32, 34), { deco = true, refl = 0.55, tr = 0.1 })
end
function P.stain(r, x, z, w, d, yaw)
	cb(r.story, "FloorStain", x, 0.045, z, w, 0.03, d, yaw or 0, M.Concrete, PAL.grime, { deco = true, tr = rand(0.45, 0.7) })
end
function P.drain(r, x, z)
	disc(r.story, "Drain", x, 0.05, z, 1.8, 0.05, M.Metal, PAL.black, DECO)
	cb(r.story, "DrainBar", x, 0.09, z, 1.5, 0.04, 0.12, 0, M.Metal, PAL.steelDark, DECO)
	cb(r.story, "DrainBar", x, 0.09, z, 0.12, 0.04, 1.5, 0, M.Metal, PAL.steelDark, DECO)
end
-- yellow/black stripe band on the floor
function P.hazardFloor(r, x0, x1, z0, z1)
	local p = bx(r.story, "HazardStripe", x0, x1, 0, 0.05, z0, z1, M.SmoothPlastic, PAL.yellow, DECO)
	hazardFace(p, NID.Top)
end
function P.lineFloor(r, x0, x1, z0, z1, color)
	bx(r.story, "FloorLine", x0, x1, 0, 0.045, z0, z1, M.SmoothPlastic, color or PAL.yellow, DECO)
end
function P.whiteboard(r, x, y, z, w, h, facing, text)
	local p = P.sign(r, text, x, y, z, w, h, facing, PAL.offwhite, C(30, 40, 90), { font = Enum.Font.Code })
	return p
end

-- ----- structures ------------------------------------------------------
function P.stairs(r, x, z, facing, width, rise, steps, run)
	local par, cf = r.props, frame(x, 0, z, facing)
	run = run or 1.4
	for i = 1, steps do
		lp(par, "Step", cf, 0, rise * i / 2, (i - 0.5) * run, width, rise * i, run, M.DiamondPlate, PAL.steelDark)
	end
	for _, sx in ipairs({ -width / 2 - 0.1, width / 2 + 0.1 }) do
		lp(par, "StairRail", cf, sx, rise * steps * 0.5 + 2.2, steps * run / 2, 0.2, 0.2, steps * run + 1, M.Metal, PAL.yellow, { deco = true, shadow = false })
		for i = 0, steps, 3 do
			lp(par, "StairPost", cf, sx, rise * math.max(i, 1) + 1.2, i * run, 0.2, 2.4, 0.2, M.Metal, PAL.yellow, DECO)
		end
	end
end
-- elevated walkway. rails: table of sides {n,s,e,w}
function P.catwalk(r, x0, x1, z0, z1, y, rails)
	local par = r.props
	bx(par, "CatwalkDeck", x0, x1, y - 0.3, y, z0, z1, M.DiamondPlate, jitter(PAL.steelDark, 0.1))
	bx(par, "CatwalkBeam", x0, x1, y - 1.1, y - 0.3, z0 + 0.2, z0 + 0.5, M.Metal, PAL.steelDark, DECO)
	bx(par, "CatwalkBeam", x0, x1, y - 1.1, y - 0.3, z1 - 0.5, z1 - 0.2, M.Metal, PAL.steelDark, DECO)
	local function railX(zz, a0, a1)
		bx(par, "Rail", a0, a1, y + 3.2, y + 3.4, zz - 0.1, zz + 0.1, M.Metal, PAL.yellow, { shadow = false })
		bx(par, "Rail", a0, a1, y + 1.6, y + 1.8, zz - 0.1, zz + 0.1, M.Metal, PAL.yellow, { shadow = false })
		local a = a0
		while a <= a1 do bx(par, "RailPost", a - 0.1, a + 0.1, y, y + 3.4, zz - 0.1, zz + 0.1, M.Metal, PAL.yellow, { shadow = false }) a += 6 end
	end
	local function railZ(xx, a0, a1)
		bx(par, "Rail", xx - 0.1, xx + 0.1, y + 3.2, y + 3.4, a0, a1, M.Metal, PAL.yellow, { shadow = false })
		bx(par, "Rail", xx - 0.1, xx + 0.1, y + 1.6, y + 1.8, a0, a1, M.Metal, PAL.yellow, { shadow = false })
		local a = a0
		while a <= a1 do bx(par, "RailPost", xx - 0.1, xx + 0.1, y, y + 3.4, a - 0.1, a + 0.1, M.Metal, PAL.yellow, { shadow = false }) a += 6 end
	end
	rails = rails or {}
	if rails.n then railX(z0 + 0.1, x0, x1) end
	if rails.s then railX(z1 - 0.1, x0, x1) end
	if rails.w then railZ(x0 + 0.1, z0, z1) end
	if rails.e then railZ(x1 - 0.1, z0, z1) end
	-- support columns
	for _, cx in ipairs({ x0 + 0.6, x1 - 0.6 }) do
		for _, cz in ipairs({ z0 + 0.6, z1 - 0.6 }) do
			bx(par, "CatwalkColumn", cx - 0.35, cx + 0.35, 0, y - 0.3, cz - 0.35, cz + 0.35, M.Metal, PAL.steelDark)
		end
	end
end
function P.forklift(r, x, z, facing)
	local par, cf = r.props, frame(x, 0, z, facing)
	local body = PAL.orange
	lp(par, "ForkliftBody", cf, 0, 1.8, -1.0, 3.6, 2.2, 5.2, M.Metal, body)
	lp(par, "ForkliftCounterweight", cf, 0, 2.2, -3.6, 3.4, 2.4, 1.0, M.Metal, shade(body, 0.7))
	lp(par, "ForkliftSeat", cf, 0, 3.3, -1.6, 2.0, 0.4, 2.0, M.Fabric, PAL.black, DECO)
	for _, sx in ipairs({ -1.5, 1.5 }) do
		lp(par, "CabPost", cf, sx, 5.2, -2.6, 0.25, 4.2, 0.25, M.Metal, PAL.black, DECO)
		lp(par, "CabPost", cf, sx, 5.2, 0.4, 0.25, 4.2, 0.25, M.Metal, PAL.black, DECO)
		lp(par, "MastRail", cf, sx * 0.5, 4.4, 2.0, 0.4, 8.6, 0.5, M.Metal, PAL.steelDark)
		lp(par, "Fork", cf, sx * 0.8, 0.6, 3.6, 0.5, 0.3, 4.6, M.Metal, PAL.steelDark)
	end
	lp(par, "CabRoof", cf, 0, 7.4, -1.1, 3.6, 0.25, 3.4, M.Metal, PAL.black, DECO)
	for _, sx in ipairs({ -1.9, 1.9 }) do
		for _, oz in ipairs({ -3.0, 1.0 }) do
			mk(par, "Wheel", Vector3.new(1.2, 2.6, 2.6), cf * CFrame.new(sx, 1.3, oz) * CFrame.Angles(0, 0, math.rad(90)), M.Rubber, PAL.black, { shape = CYL, shadow = false, deco = true })
		end
	end
end
function P.cart(r, x, z, facing, loaded)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "CartDeck", cf, 0, 1.2, 0, 3.4, 0.2, 2.2, M.Metal, PAL.steelDark)
	lp(par, "CartShelf", cf, 0, 2.7, 0, 3.4, 0.2, 2.2, M.Metal, PAL.steelDark)
	for _, sx in ipairs({ -1.6, 1.6 }) do
		lp(par, "CartPost", cf, sx, 2.0, -1.0, 0.2, 2.8, 0.2, M.Metal, PAL.steelDark)
		lp(par, "CartPost", cf, sx, 2.0, 1.0, 0.2, 2.8, 0.2, M.Metal, PAL.steelDark)
		for _, oz in ipairs({ -0.9, 0.9 }) do
			mk(par, "Caster", Vector3.new(0.3, 0.7, 0.7), cf * CFrame.new(sx, 0.4, oz) * CFrame.Angles(0, 0, math.rad(90)), M.Rubber, PAL.black, { shape = CYL, deco = true })
		end
	end
	if loaded then
		lp(par, "CartToolbox", cf, -0.6, 1.6, 0, 1.4, 0.8, 1.0, M.Metal, PAL.red, DECO)
		lp(par, "CartCan", cf, 0.9, 3.1, 0, 0.7, 0.8, 0.7, M.Metal, PAL.yellow, DECO)
	end
end
function P.detector(r, x, z, facing, ok)
	local par, cf = r.props, frame(x, 0, z, facing)
	for _, sx in ipairs({ -1.8, 1.8 }) do lp(par, "DetectorPost", cf, sx, 3.6, 0, 0.7, 7.2, 1.6, M.Metal, PAL.offwhite) end
	lp(par, "DetectorTop", cf, 0, 7.4, 0, 4.3, 0.8, 1.6, M.Metal, PAL.offwhite)
	local led = lp(par, "DetectorLight", cf, 0, 7.4, 0.85, 1.2, 0.35, 0.05, M.Neon, ok and PAL.green or PAL.red, DECO)
	if not ok then tag(led, "PulseLight") led:SetAttribute("Speed", 1.2) end
end
function P.keycardReader(r, x, y, z, facing, id, state)
	local par, cf = r.props, frame(x, y, z, facing)
	local body = lp(par, "KeycardReader", cf, 0, 0, 0.15, 0.9, 1.4, 0.3, M.Metal, PAL.black, DECO)
	local col = state == "unlocked" and PAL.green or (state == "dead" and PAL.black or PAL.red)
	lp(par, "ReaderLED", cf, 0, 0.35, 0.33, 0.3, 0.2, 0.05, M.Neon, col, DECO)
	lp(par, "ReaderSlot", cf, 0, -0.1, 0.33, 0.6, 0.08, 0.05, M.Metal, PAL.steelLight, DECO)
	body:SetAttribute("DoorId", id or "")
	tag(body, "KeycardReader")
end
function P.sandbag(r, x, z, facing, n)
	local cf = frame(x, 0, z, facing)
	for i = 0, n - 1 do
		lp(r.props, "Sandbag", cf, i * 1.6, 0.5, 0, 1.7, 1.0, 1.0, M.Fabric, jitter(C(130, 118, 90), 0.1))
		if i < n - 1 then lp(r.props, "Sandbag", cf, i * 1.6 + 0.8, 1.45, 0, 1.7, 0.9, 1.0, M.Fabric, jitter(C(130, 118, 90), 0.1)) end
	end
end

-- claw gouges on a wall (scary story detail). x,y,z at wall face, facing = wall normal
function P.claw(r, x, y, z, facing, n)
	local cf = frame(x, y, z, facing)
	for i = 1, (n or 4) do
		lp(r.story, "ClawMark", cf, (i - (n or 4) / 2 - 0.5) * 0.55, rand(-0.2, 0.2), 0.04, 0.13, rand(3.2, 4.8), 0.05, M.Concrete, C(36, 33, 30), { deco = true, tr = 0.1 })
	end
end
-- scattered glass fragments
function P.shards(r, x, z, radius, n)
	n = math.floor(n * math.max(CFG.DETAIL, 0.3))
	for _ = 1, n do
		local a, d = rand(0, 6.28), rand(0, radius)
		cb(r.story, "GlassShard", x + math.cos(a) * d, 0.08, z + math.sin(a) * d, rand(0.3, 0.9), 0.04, rand(0.3, 1.0), rand(0, 6.28),
			M.Glass, C(190, 220, 220), { deco = true, tr = 0.45 })
	end
end
