--!nocheck
-- MapInventory.luau
-- Paste into Roblox Studio: View > Command Bar, then press Enter.
-- READ-ONLY survey of the place. The only thing it creates is a disabled Script
-- named "MapReport" in ServerStorage that holds the report text (easy to copy).
-- Run it in Edit mode (not while playtesting).

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local MAX_LIST = 300 -- cap per list so the report stays pasteable

local out = {}
local function add(s) out[#out + 1] = s end
local function f(n) return string.format("%.0f", n) end
local function v3(v) return f(v.X) .. "," .. f(v.Y) .. "," .. f(v.Z) end

local function pivotOf(m)
	local ok, p = pcall(function() return m:GetPivot().Position end)
	if ok then return p end
	return nil
end

local function posOf(i)
	if i:IsA("BasePart") then return i.Position end
	if i:IsA("Model") then return pivotOf(i) end
	local part = i:FindFirstAncestorWhichIsA("BasePart")
	if part then return part.Position end
	local model = i:FindFirstAncestorWhichIsA("Model")
	if model then return pivotOf(model) end
	return nil
end

local function posStr(i)
	local p = posOf(i)
	return p and v3(p) or "?"
end

-- approximate extent: min/max of part centres + count of parts
local function survey(root)
	local mn, mx
	local parts, total = 0, 0
	for _, d in ipairs(root:GetDescendants()) do
		total += 1
		if d:IsA("BasePart") then
			parts += 1
			local p = d.Position
			if not mn then
				mn, mx = p, p
			else
				mn = Vector3.new(math.min(mn.X, p.X), math.min(mn.Y, p.Y), math.min(mn.Z, p.Z))
				mx = Vector3.new(math.max(mx.X, p.X), math.max(mx.Y, p.Y), math.max(mx.Z, p.Z))
			end
		end
	end
	if root:IsA("BasePart") then parts += 1 end
	return parts, total, mn, mx
end

local function section(title)
	add("")
	add("=== " .. title .. " ===")
end

------------------------------------------------------------------ 1. overview
section("1. WORKSPACE OVERVIEW")
add("Place: " .. game.Name .. " (PlaceId " .. tostring(game.PlaceId) .. ")")
pcall(function() add("StreamingEnabled: " .. tostring(workspace.StreamingEnabled)) end)
pcall(function() add("Gravity: " .. tostring(workspace.Gravity)) end)

local classCount, matCount = {}, {}
local anchored, unanchored, canCollideOff, lights = 0, 0, 0, 0
local lightClasses = { PointLight = true, SpotLight = true, SurfaceLight = true }
local totalParts = 0
local all = workspace:GetDescendants()
for _, d in ipairs(all) do
	classCount[d.ClassName] = (classCount[d.ClassName] or 0) + 1
	if d:IsA("BasePart") then
		totalParts += 1
		local m = d.Material.Name
		matCount[m] = (matCount[m] or 0) + 1
		if d.Anchored then anchored += 1 else unanchored += 1 end
		if not d.CanCollide then canCollideOff += 1 end
	elseif lightClasses[d.ClassName] then
		lights += 1
	end
end
add("Total instances in Workspace: " .. #all)
add("BaseParts: " .. totalParts .. "  (anchored " .. anchored .. ", unanchored " .. unanchored
	.. ", CanCollide=false " .. canCollideOff .. ")")
add("Lights (Point/Spot/Surface): " .. lights)

local function sortedPairs(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return t[a] > t[b] end)
	return keys
end
local line = {}
for _, k in ipairs(sortedPairs(classCount)) do
	if #line < 25 then line[#line + 1] = k .. "=" .. classCount[k] end
end
add("Top classes: " .. table.concat(line, ", "))
line = {}
for _, k in ipairs(sortedPairs(matCount)) do line[#line + 1] = k .. "=" .. matCount[k] end
add("Materials: " .. table.concat(line, ", "))

------------------------------------------------------------------ 2. hierarchy
section("2. HIERARCHY (top 3 levels; bbox = min->max of part centres)")
local function describe(inst, depth)
	local parts, total, mn, mx = survey(inst)
	local box = mn and (" bbox " .. v3(mn) .. " -> " .. v3(mx)) or ""
	add(string.rep("  ", depth) .. inst.Name .. " [" .. inst.ClassName .. "] parts=" .. parts
		.. " desc=" .. total .. box)
end
local function walk(inst, depth)
	local kids = inst:GetChildren()
	local containers = {}
	for _, k in ipairs(kids) do
		if k:IsA("Model") or k:IsA("Folder") then containers[#containers + 1] = k end
	end
	local shown = 0
	for _, k in ipairs(containers) do
		if shown >= 60 then
			add(string.rep("  ", depth) .. "... +" .. (#containers - shown) .. " more containers")
			break
		end
		shown += 1
		describe(k, depth)
		if depth < 3 then walk(k, depth + 1) end
	end
end
for _, c in ipairs(workspace:GetChildren()) do
	if c:IsA("Terrain") or c:IsA("Camera") then continue end
	if c:IsA("Model") or c:IsA("Folder") then
		describe(c, 0)
		walk(c, 1)
	else
		add(c.Name .. " [" .. c.ClassName .. "] at " .. posStr(c))
	end
end

------------------------------------------------------------------ 3. keyword hits
section("3. GAMEPLAY-NAMED OBJECTS (name contains a keyword; topmost match only)")
local KEYWORDS = {
	"chest", "loot", "extract", "exfil", "spawn", "door", "keycard", "keypad", "npc", "enemy",
	"boss", "zone", "elevator", "safe", "crate", "terminal", "generator", "lever", "button",
	"gate", "vent", "stair", "ladder", "room", "lab", "hall", "corridor", "storage", "security",
	"medical", "reactor", "tunnel",
}
local hits = {}
for _, k in ipairs(KEYWORDS) do hits[k] = {} end
local covered = {}
for _, d in ipairs(all) do
	local parentCovered = covered[d.Parent] or false
	covered[d] = parentCovered
	if parentCovered then continue end
	if not (d:IsA("BasePart") or d:IsA("Model") or d:IsA("Folder")) then continue end
	local lname = d.Name:lower()
	for _, k in ipairs(KEYWORDS) do
		if lname:find(k, 1, true) then
			table.insert(hits[k], d)
			if d:IsA("Model") or d:IsA("BasePart") then covered[d] = true end
			break
		end
	end
end
for _, k in ipairs(KEYWORDS) do
	local list = hits[k]
	if #list > 0 then
		add("-- '" .. k .. "' (" .. #list .. ")")
		for i, d in ipairs(list) do
			if i > MAX_LIST then add("   ... capped"); break end
			local size = ""
			if d:IsA("BasePart") then
				size = " size " .. v3(d.Size)
			elseif d:IsA("Model") then
				local ok, sz = pcall(function() return d:GetExtentsSize() end)
				if ok then size = " size " .. v3(sz) end
			end
			local attrs = {}
			for an, av in pairs(d:GetAttributes()) do attrs[#attrs + 1] = an .. "=" .. tostring(av) end
			add("   " .. d:GetFullName() .. " [" .. d.ClassName .. "] at " .. posStr(d) .. size
				.. (#attrs > 0 and (" attrs{" .. table.concat(attrs, ";") .. "}") or ""))
		end
	end
end

------------------------------------------------------------------ 4. interactables
section("4. INTERACTABLES")
local prompts, clicks, spawns, humanoids = {}, {}, {}, {}
for _, d in ipairs(all) do
	if d:IsA("ProximityPrompt") then
		prompts[#prompts + 1] = d
	elseif d:IsA("ClickDetector") then
		clicks[#clicks + 1] = d
	elseif d:IsA("SpawnLocation") then
		spawns[#spawns + 1] = d
	elseif d:IsA("Humanoid") then
		local model = d.Parent
		if model and not Players:GetPlayerFromCharacter(model) then humanoids[#humanoids + 1] = d end
	end
end
add("-- ProximityPrompts (" .. #prompts .. ")")
for i, p in ipairs(prompts) do
	if i > MAX_LIST then add("   ... capped"); break end
	add("   " .. p:GetFullName() .. " action='" .. p.ActionText .. "' object='" .. p.ObjectText
		.. "' at " .. posStr(p))
end
add("-- ClickDetectors (" .. #clicks .. ")")
for i, c in ipairs(clicks) do
	if i > MAX_LIST then add("   ... capped"); break end
	add("   " .. c:GetFullName() .. " at " .. posStr(c))
end
add("-- SpawnLocations (" .. #spawns .. ")")
for _, s in ipairs(spawns) do
	add("   " .. s:GetFullName() .. " at " .. v3(s.Position) .. " size " .. v3(s.Size)
		.. " team=" .. tostring(s.TeamColor) .. " neutral=" .. tostring(s.Neutral))
end
add("-- Non-player Humanoids / NPCs (" .. #humanoids .. ")")
for i, h in ipairs(humanoids) do
	if i > MAX_LIST then add("   ... capped"); break end
	add("   " .. h.Parent:GetFullName() .. " at " .. posStr(h.Parent) .. " health=" .. h.MaxHealth)
end

------------------------------------------------------------------ 5. tags
section("5. COLLECTIONSERVICE TAGS")
for _, tag in ipairs(CollectionService:GetAllTags()) do
	local tagged = CollectionService:GetTagged(tag)
	add("-- '" .. tag .. "' (" .. #tagged .. ")")
	for i, inst in ipairs(tagged) do
		if i > 8 then add("   ..."); break end
		add("   " .. inst:GetFullName() .. " at " .. posStr(inst))
	end
end

------------------------------------------------------------------ 6. lighting
section("6. LIGHTING")
local function prop(obj, name)
	local ok, v = pcall(function() return obj[name] end)
	return ok and tostring(v) or "?"
end
for _, name in ipairs({
	"Technology", "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation",
	"GlobalShadows", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "FogStart", "FogEnd", "FogColor",
}) do
	add(name .. ": " .. prop(Lighting, name))
end
for _, c in ipairs(Lighting:GetChildren()) do
	add("child: " .. c.Name .. " [" .. c.ClassName .. "]")
end

------------------------------------------------------------------ 7. scripts
section("7. SCRIPTS (path, class; no source)")
local roots = {
	workspace, game:GetService("ServerScriptService"), game:GetService("ReplicatedStorage"),
	ServerStorage, game:GetService("ReplicatedFirst"), game:GetService("StarterPlayer"),
	game:GetService("StarterGui"), game:GetService("StarterPack"),
}
for _, root in ipairs(roots) do
	local n = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("LuaSourceContainer") and d.Name ~= "MapReport" then
			n += 1
			if n <= MAX_LIST then add("   " .. d:GetFullName() .. " [" .. d.ClassName .. "]") end
		end
	end
	if n > MAX_LIST then add("   ... " .. (n - MAX_LIST) .. " more in " .. root.Name) end
end

section("8. OTHER SERVICES (top-level children, for templates/chest models)")
for _, root in ipairs({ game:GetService("ReplicatedStorage"), ServerStorage }) do
	add("-- " .. root.Name)
	for _, c in ipairs(root:GetChildren()) do
		if c.Name ~= "MapReport" then add("   " .. c.Name .. " [" .. c.ClassName .. "] kids=" .. #c:GetChildren()) end
	end
end

------------------------------------------------------------------ output
local text = table.concat(out, "\n")
local saved = pcall(function()
	local old = ServerStorage:FindFirstChild("MapReport")
	if old then old:Destroy() end
	local s = Instance.new("Script")
	s.Name = "MapReport"
	s.Enabled = false
	s.Source = "--[==[\n" .. text .. "\n]==]"
	s.Parent = ServerStorage
end)

print(("MapInventory done: %d lines, %d chars. %s"):format(#out, #text,
	saved and "Report also saved to ServerStorage.MapReport (open it and copy all)."
		or "Could not create MapReport; copy from the Output window."))
local chunk, size = {}, 0
for _, l in ipairs(out) do
	chunk[#chunk + 1] = l
	size += #l + 1
	if size > 6000 then
		print(table.concat(chunk, "\n"))
		chunk, size = {}, 0
	end
end
if #chunk > 0 then print(table.concat(chunk, "\n")) end
