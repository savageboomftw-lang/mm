-- dump scene for the python preview renderer
local function topRoom(p)
	local t = p
	while t.Parent and t.Parent ~= root do t = t.Parent end
	return t.Name
end
for _, p in ipairs(MOCK_ALL_PARTS()) do
	if p.Parent and p:IsDescendantOf(root) then
		local r = p.CFrame.r
		local c = p.CFrame.p
		local col = p.Color
		print(string.format("PART\t%s\t%.3f %.3f %.3f\t%.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f\t%.3f %.3f %.3f\t%.3f %.3f %.3f\t%s\t%.2f\t%s\t%s\t%s",
			topRoom(p), c.X, c.Y, c.Z, r[1][1], r[1][2], r[1][3], r[2][1], r[2][2], r[2][3], r[3][1], r[3][2], r[3][3],
			p.Size.X, p.Size.Y, p.Size.Z, col.R, col.G, col.B, tostring(p.Material), p.Transparency or 0, tostring(p.Shape), p.Name,
			p.CanCollide and "1" or "0"))
		for _, ch in ipairs(p:GetChildren()) do
			if ch:IsA("Light") then
				local lc = ch.Color
				print(string.format("LIGHT\t%s\t%.2f %.2f %.2f\t%.3f %.3f %.3f\t%.3f\t%.1f\t%s", topRoom(p), c.X, c.Y, c.Z, lc.R, lc.G, lc.B, ch.Brightness, ch.Range, ch.ClassName))
			end
		end
	end
end
