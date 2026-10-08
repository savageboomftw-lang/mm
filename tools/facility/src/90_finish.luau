
-- ---------------------------------------------------------------- finish
buildAllDoorways()

if CFG.ORIGIN ~= Vector3.zero then
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then d.CFrame = d.CFrame + CFG.ORIGIN end
	end
end

local nParts, nLights = 0, 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("BasePart") then nParts += 1 end
	if d:IsA("Light") then nLights += 1 end
end
print(("[Facility] built: %d parts, %d lights, %d chests. Hit Play - spawn is in Reception."):format(nParts, nLights, chestCount))
if FACILITY_TEST_HOOK then FACILITY_TEST_HOOK({ DW = DW, ROOMS = ROOMS }) end -- only defined by the headless test harness
return root
