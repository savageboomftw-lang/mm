--!nocheck
-- Minimal headless mock of the Roblox API: just enough to execute FacilityBuilder
-- outside Studio, record every part, and run geometry / walkability checks.

local Vec3 = {}
Vec3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		if m == 0 then return t end
		return Vector3.new(t.X / m, t.Y / m, t.Z / m)
	end
	return rawget(Vec3, k)
end
Vec3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vec3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vec3.__mul = function(a, b)
	if type(a) == "number" then return Vector3.new(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vec3.__div = function(a, b)
	if type(b) == "number" then return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vec3.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
Vec3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3 = {
	new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vec3) end,
}
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)

Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end }
UDim = { new = function(s, o) return { Scale = s, Offset = o } end }
UDim2 = {
	new = function(a, b, c, d) return { a, b, c, d } end,
	fromScale = function(a, b) return { a, b } end,
	fromOffset = function(a, b) return { a, b } end,
}
NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end }
NumberSequenceKeypoint = { new = function(t, v, e) return { Time = t, Value = v } end }
NumberSequence = {
	new = function(a, b)
		if type(a) == "table" then
			for i = 2, #a do
				assert(a[i].Time > a[i - 1].Time or a[i].Time == a[i - 1].Time, "NumberSequence not ordered")
			end
			assert(a[1].Time == 0 and a[#a].Time == 1, "NumberSequence must span 0..1")
		end
		return { a, b }
	end,
}
ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
ColorSequence = {
	new = function(a, b)
		if type(a) == "table" and a[1] and a[1].Time then
			assert(#a <= 20, "ColorSequence >20 keypoints")
			assert(a[1].Time == 0 and a[#a].Time == 1, "ColorSequence must span 0..1")
			for i = 2, #a do assert(a[i].Time > a[i - 1].Time, "ColorSequence times must strictly increase") end
		end
		return { a, b }
	end,
}
Color3 = {}
Color3.new = function(r, g, b) return { R = r, G = g, B = b } end
Color3.fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end
Color3.fromHSV = function(h, s, v) return { R = v, G = v, B = v } end

-- CFrame: position + 3x3 rotation matrix
local CF = {}
local function mat3mul(a, b)
	local r = {}
	for i = 1, 3 do
		r[i] = {}
		for j = 1, 3 do
			r[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
		end
	end
	return r
end
local I3 = function() return { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } } end
CF.__index = function(t, k)
	if k == "Position" then return t.p end
	if k == "X" then return t.p.X end
	if k == "Y" then return t.p.Y end
	if k == "Z" then return t.p.Z end
	if k == "LookVector" then return Vector3.new(-t.r[1][3], -t.r[2][3], -t.r[3][3]) end
	if k == "RightVector" then return Vector3.new(t.r[1][1], t.r[2][1], t.r[3][1]) end
	if k == "UpVector" then return Vector3.new(t.r[1][2], t.r[2][2], t.r[3][2]) end
	if k == "Rotation" then return setmetatable({ p = Vector3.zero, r = t.r }, CF) end
	if k == "Inverse" then
		return function(self)
			local rt = { {}, {}, {} }
			for i = 1, 3 do for j = 1, 3 do rt[i][j] = self.r[j][i] end end
			local np = Vector3.new(
				-(rt[1][1] * self.p.X + rt[1][2] * self.p.Y + rt[1][3] * self.p.Z),
				-(rt[2][1] * self.p.X + rt[2][2] * self.p.Y + rt[2][3] * self.p.Z),
				-(rt[3][1] * self.p.X + rt[3][2] * self.p.Y + rt[3][3] * self.p.Z))
			return setmetatable({ p = np, r = rt }, CF)
		end
	end
	if k == "ToWorldSpace" then return function(self, o) return self * o end end
	return nil
end
CF.__mul = function(a, b)
	if getmetatable(b) == Vec3 then
		local r = a.r
		return Vector3.new(
			r[1][1] * b.X + r[1][2] * b.Y + r[1][3] * b.Z + a.p.X,
			r[2][1] * b.X + r[2][2] * b.Y + r[2][3] * b.Z + a.p.Y,
			r[3][1] * b.X + r[3][2] * b.Y + r[3][3] * b.Z + a.p.Z)
	end
	local np = a * b.p
	return setmetatable({ p = np, r = mat3mul(a.r, b.r) }, CF)
end
CF.__add = function(a, v) return setmetatable({ p = a.p + v, r = a.r }, CF) end
CF.__sub = function(a, v) return setmetatable({ p = a.p - v, r = a.r }, CF) end
CFrame = {}
CFrame.new = function(x, y, z)
	if x == nil then return setmetatable({ p = Vector3.zero, r = I3() }, CF) end
	if type(x) == "table" and getmetatable(x) == Vec3 then
		if y ~= nil then
			-- CFrame.new(pos, lookAt): yaw only
			local d = y - x
			local yaw = math.atan2(-d.X, -d.Z)
			local c, s = math.cos(yaw), math.sin(yaw)
			return setmetatable({ p = x, r = { { c, 0, s }, { 0, 1, 0 }, { -s, 0, c } } }, CF)
		end
		return setmetatable({ p = x, r = I3() }, CF)
	end
	return setmetatable({ p = Vector3.new(x, y, z), r = I3() }, CF)
end
CFrame.Angles = function(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local Rx = { { 1, 0, 0 }, { 0, cx, -sx }, { 0, sx, cx } }
	local Ry = { { cy, 0, sy }, { 0, 1, 0 }, { -sy, 0, cy } }
	local Rz = { { cz, -sz, 0 }, { sz, cz, 0 }, { 0, 0, 1 } }
	return setmetatable({ p = Vector3.zero, r = mat3mul(mat3mul(Rx, Ry), Rz) }, CF)
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
CFrame.identity = CFrame.new()

-- Enum: any Enum.A.B resolves to the string "A.B"
Enum = setmetatable({}, { __index = function(t, k)
	local sub = setmetatable({}, { __index = function(_, v) return k .. "." .. v end })
	rawset(t, k, sub)
	return sub
end })

-- Random
Random = { new = function(seed)
	local state = (seed or 1) % 2147483647
	if state <= 0 then state += 2147483646 end
	local function nxt()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	local o = {}
	function o:NextNumber(a, b)
		local u = nxt()
		if a == nil then return u end
		return a + (b - a) * u
	end
	function o:NextInteger(a, b) return a + math.floor(nxt() * (b - a + 1)) end
	return o
end }

-- Instance
local ALL = {}
local PARTS = { Part = true, WedgePart = true, TrussPart = true, SpawnLocation = true, MeshPart = true }
local PARENTS = {
	Part = "BasePart", WedgePart = "BasePart", SpawnLocation = "BasePart", MeshPart = "BasePart",
	BasePart = "PVInstance", Model = "PVInstance", Folder = "Instance", Script = "LuaSourceContainer",
	LocalScript = "LuaSourceContainer", ModuleScript = "LuaSourceContainer",
	PointLight = "Light", SpotLight = "Light", SurfaceLight = "Light",
	Light = "Instance", PVInstance = "Instance", LuaSourceContainer = "Instance",
}
local Inst = {}
local function isA(cls, name)
	while cls do
		if cls == name then return true end
		cls = PARENTS[cls]
	end
	return false
end
Inst.__index = function(t, k)
	local m = rawget(Inst, k)
	if m then return m end
	if k == "Parent" then return rawget(t, "_parent") end
	if k == "Position" and rawget(t, "CFrame") then return rawget(t, "CFrame").p end
	return nil
end
Inst.__newindex = function(t, k, v)
	if k == "Parent" then
		local old = rawget(t, "_parent")
		if old then
			for i, c in ipairs(old._children) do if c == t then table.remove(old._children, i) break end end
		end
		rawset(t, "_parent", v)
		if v then table.insert(v._children, t) end
		return
	end
	if k == "Position" and rawget(t, "CFrame") then
		rawset(t, "CFrame", CFrame.new(v) * rawget(t, "CFrame").Rotation)
		return
	end
	rawset(t, k, v)
end
function Inst.IsA(self, n) return isA(self.ClassName, n) end
function Inst.GetChildren(self) return { table.unpack(self._children) } end
function Inst.GetDescendants(self)
	local out = {}
	local function rec(n) for _, c in ipairs(n._children) do out[#out + 1] = c rec(c) end end
	rec(self)
	return out
end
function Inst.FindFirstChild(self, name)
	for _, c in ipairs(self._children) do if c.Name == name then return c end end
	return nil
end
function Inst.FindFirstChildOfClass(self, cls)
	for _, c in ipairs(self._children) do if c.ClassName == cls then return c end end
	return nil
end
function Inst.Destroy(self) self.Parent = nil end
function Inst.SetAttribute(self, k, v) self._attrs[k] = v end
function Inst.GetAttribute(self, k) return self._attrs[k] end
function Inst.GetAttributes(self) return self._attrs end
function Inst.GetFullName(self)
	local n, p = self.Name, self.Parent
	while p and p.ClassName ~= "DataModel" do n = p.Name .. "." .. n p = p.Parent end
	return n
end
function Inst.GetPivot(self) return CFrame.new() end
function Inst.PivotTo(self, cf) end
function Inst.IsDescendantOf(self, a)
	local p = self.Parent
	while p do if p == a then return true end p = p.Parent end
	return false
end

Instance = { new = function(cls, parent)
	local o = setmetatable({ ClassName = cls, Name = cls, _children = {}, _attrs = {}, _tags = {} }, Inst)
	if PARTS[cls] then
		o.Size = Vector3.new(2, 1, 2)
		o.CFrame = CFrame.new()
		o.CanCollide = true
		o.CanQuery = true
		o.CanTouch = true
		o.Anchored = false
		o.Transparency = 0
		o.Shape = "PartType.Block"
		o.Material = "Material.Plastic"
		o.Color = Color3.fromRGB(163, 162, 165)
		ALL[#ALL + 1] = o
	end
	if parent then o.Parent = parent end
	return o
end }

local function service(name)
	local s = Instance.new(name == "Workspace" and "Workspace" or name)
	s.Name = name
	return s
end
local SERVICES = {}
local DataModel = Instance.new("DataModel")
DataModel.Name = "Game"
function DataModel.GetService(self, name)
	if not SERVICES[name] then
		local s = Instance.new(name)
		s.Name = name
		s.Parent = DataModel
		SERVICES[name] = s
		if name == "StarterPlayer" then
			local sp = Instance.new("StarterPlayerScripts")
			sp.Parent = s
		end
		if name == "CollectionService" then
			function s:AddTag(inst, tag) inst._tags[tag] = true self._all = self._all or {} self._all[tag] = self._all[tag] or {} table.insert(self._all[tag], inst) end
			function s:GetTagged(tag) return (self._all or {})[tag] or {} end
			function s:HasTag(inst, tag) return inst._tags[tag] == true end
		end
	end
	return SERVICES[name]
end
game = DataModel
workspace = game:GetService("Workspace")
function MOCK_ALL_PARTS() return ALL end
function MOCK_IS_A(o, n) return isA(o.ClassName, n) end
