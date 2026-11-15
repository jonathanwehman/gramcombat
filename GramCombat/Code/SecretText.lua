-- Gram Combat: hidden-number display.
--
-- On WoW Forever the game hands addons damage and heal amounts as hidden
-- ("secret") values. An addon can't read them, add them or compare them, but
-- it CAN pass them straight to a text widget, which shows the real number.
-- This file does exactly that: it never touches the number itself, it only
-- hands it to SetFormattedText inside the same scroll areas as everything else.
local _, ns = ...
local C = ns.C

local GetTime = GetTime
local LSM = LibStub("LibSharedMedia-3.0")

local Secret = {}
ns.Secret = Secret

local HOLDER = CreateFrame("Frame", "GramCombatSecretFrame", UIParent)
HOLDER:SetFrameStrata("HIGH")
HOLDER:SetAllPoints(UIParent)

-- school colors (hex)
local SCHOOL_COLORS = {
	[1] = "ffffff", [2] = "ffe680", [4] = "ff8c1a", [8] = "66ff66",
	[16] = "80dfff", [32] = "a680ff", [64] = "ff80ff",
}
local function SchoolColor(school)
	return SCHOOL_COLORS[school] or "ffd24d"
end
Secret.SchoolColor = SchoolColor

local function Areas()
	local Parrot = ns.addon
	local ns_ = Parrot and Parrot.db and Parrot.db:GetNamespace("ScrollAreas", true)
	return ns_ and ns_.profile.areas
end

local function DisplayDB()
	local Parrot = ns.addon
	local d = Parrot and Parrot.db and Parrot.db:GetNamespace("Display", true)
	return d and d.profile
end

local function FontPath(sticky)
	local db = DisplayDB()
	local name = db and (sticky and db.stickyFont or db.font)
	local path = name and LSM:Fetch("font", name, true)
	return path or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

-------------------------------------------------------------------------------
-- line pool
-------------------------------------------------------------------------------
local pool, active = {}, {}

local function NewLine()
	local l = table.remove(pool)
	if l then return l end
	l = CreateFrame("Frame", nil, HOLDER)
	l:SetSize(1, 1)
	l.fs = l:CreateFontString(nil, "OVERLAY")
	l.icon = l:CreateTexture(nil, "OVERLAY")
	l.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	return l
end

local function Release(l)
	l:Hide()
	l.icon:Hide()
	l.fs:SetText("")
	pool[#pool + 1] = l
end

-------------------------------------------------------------------------------
-- animation: straight scroll, newest line pushes older ones along
-------------------------------------------------------------------------------
local animator = CreateFrame("Frame")
animator:Hide()

local function Place(l)
	local a = l.area
	local vert, align = (";"):split(a.direction or "DOWN;CENTER")
	local size = a.size or 150
	local travel = l.dist
	local y
	if vert == "UP" then
		y = (a.yOffset or 0) - size / 2 + travel
	else
		y = (a.yOffset or 0) + size / 2 - travel
	end
	local point = (align == "LEFT" or align == "RIGHT") and align or "CENTER"
	l:ClearAllPoints()
	l:SetPoint(point, UIParent, "CENTER", a.xOffset or 0, y)
end

animator:SetScript("OnUpdate", function(self, elapsed)
	local now = GetTime()
	for i = #active, 1, -1 do
		local l = active[i]
		local a = l.area
		local size = a.size or 150
		local speed = size / (a.speed or 3)
		l.dist = l.dist + speed * elapsed
		local done = l.dist / size
		if done >= 1 then
			table.remove(active, i)
			Release(l)
		else
			if done > 0.8 then l:SetAlpha((1 - done) / 0.2) else l:SetAlpha(1) end
			Place(l)
		end
	end
	if #active == 0 then self:Hide() end
end)

-- keep lines in the same area at least one line-height apart
local function Bump(newLine)
	local gap = newLine.height
	local prev = newLine
	for i = #active, 1, -1 do
		local l = active[i]
		if l ~= newLine and l.areaName == newLine.areaName then
			local need = prev.dist + math.max(prev.height, l.height) * 0.9
			if l.dist < need then l.dist = need end
			prev = l
		end
	end
end

-------------------------------------------------------------------------------
-- public: Secret:Show(areaName, fmt, value, opts)
--   fmt    plain format string with exactly one %s for the hidden value
--   opts   { color = "rrggbb", icon = texture, crit = bool }
-------------------------------------------------------------------------------
function Secret:Show(areaName, fmt, value, opts)
	local areas = Areas()
	local a = areas and areas[areaName]
	if not a then return end
	opts = opts or {}
	local db = DisplayDB() or {}
	local crit = opts.crit
	local fontSize = crit and (db.stickyFontSize or 20) or (db.fontSize or 14)
	local outline = (crit and db.stickyFontOutline or db.fontOutline) or "OUTLINE"
	if outline == "NONE" then outline = "" end

	local l = NewLine()
	l.area, l.areaName = a, areaName
	l.dist = 0
	l.height = fontSize + 2
	local fs = l.fs
	fs:SetFont(FontPath(crit), fontSize, outline)
	if db.fontShadow ~= false then
		fs:SetShadowColor(0, 0, 0, 1); fs:SetShadowOffset(1, -1)
	else
		fs:SetShadowOffset(0, 0)
	end

	local full = "|cff" .. (opts.color or "ffffff") .. fmt .. "|r"
	local ok = pcall(fs.SetFormattedText, fs, full, value)
	if not ok then
		ok = pcall(fs.SetText, fs, value)
		if ok then
			local r, g, b = tonumber((opts.color or "ffffff"):sub(1, 2), 16) / 255,
				tonumber((opts.color or "ffffff"):sub(3, 4), 16) / 255,
				tonumber((opts.color or "ffffff"):sub(5, 6), 16) / 255
			fs:SetTextColor(r, g, b)
		end
	else
		fs:SetTextColor(1, 1, 1)
	end
	if not ok then Release(l) return end

	-- layout without measuring the (hidden) text
	local _, align = (";"):split(a.direction or "DOWN;CENTER")
	local iconSide = a.iconSide or "LEFT"
	local showIcon = opts.icon and (db.iconsEnabled ~= false)
	local isz = fontSize + 2
	fs:ClearAllPoints()
	l.icon:ClearAllPoints()
	if showIcon then
		l.icon:SetTexture(opts.icon)
		l.icon:SetSize(isz, isz)
		l.icon:SetAlpha(db.iconAlpha or 1)
		l.icon:Show()
	else
		l.icon:Hide()
	end
	if align == "RIGHT" then
		if showIcon and iconSide == "RIGHT" then
			l.icon:SetPoint("RIGHT", l, "CENTER", 0, 0)
			fs:SetPoint("RIGHT", l.icon, "LEFT", -3, 0)
		else
			fs:SetPoint("RIGHT", l, "CENTER", 0, 0)
			if showIcon then l.icon:SetPoint("RIGHT", fs, "LEFT", -3, 0) end
		end
	elseif align == "LEFT" then
		if showIcon and iconSide ~= "RIGHT" then
			l.icon:SetPoint("LEFT", l, "CENTER", 0, 0)
			fs:SetPoint("LEFT", l.icon, "RIGHT", 3, 0)
		else
			fs:SetPoint("LEFT", l, "CENTER", 0, 0)
			if showIcon then l.icon:SetPoint("LEFT", fs, "RIGHT", 3, 0) end
		end
	else
		fs:SetPoint("CENTER", l, "CENTER", 0, 0)
		if showIcon then l.icon:SetPoint("RIGHT", fs, "LEFT", -3, 0) end
	end

	l:SetAlpha(1)
	l:Show()
	active[#active + 1] = l
	Bump(l)
	Place(l)
	animator:Show()
end

function Secret:Clear()
	for i = #active, 1, -1 do Release(active[i]); active[i] = nil end
	animator:Hide()
end
