-- Gram Combat: the settings panel and the drag-to-move boxes.
-- Flat dark style with a pink accent, to match Gram Frames.
local _, ns = ...

local LSM = LibStub("LibSharedMedia-3.0")
local FLAT = "Interface\\Buttons\\WHITE8X8"
local ACCENT = { 1, 0.31, 0.64 }       -- ff4fa3
local BG = { 0.11, 0.11, 0.12 }
local PANEL = { 0.15, 0.15, 0.16 }
local BORDER = { 0, 0, 0 }
local TEXT = { 0.92, 0.92, 0.94 }
local MUTED = { 0.62, 0.62, 0.66 }

local UI = {}
ns.UI = UI

local function Parrot() return ns.addon end
local function NS(name)
	local p = Parrot()
	local n = p and p.db and p.db:GetNamespace(name, true)
	return n and n.profile
end

local function Font()
	return LSM:Fetch("font", "Expressway", true) or "Fonts\\ARIALN.TTF"
end

local function Tex(parent, layer, col, a)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	t:SetTexture(FLAT)
	t:SetVertexColor(col[1], col[2], col[3], a or 1)
	return t
end

local function Fill(f, col, a)
	local t = Tex(f, "BACKGROUND", col, a)
	t:SetAllPoints()
	f.fill = t
	return t
end

local function Border(f, col, a)
	col = col or BORDER
	local edges = {}
	for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local t = Tex(f, "BORDER", col, a)
		if side == "TOP" or side == "BOTTOM" then
			t:SetHeight(1)
			t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT")
		else
			t:SetWidth(1)
			t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side)
		end
		edges[#edges + 1] = t
	end
	f.border = edges
	function f:SetBorderColor(r, g, b, alpha)
		for _, t in ipairs(edges) do t:SetVertexColor(r, g, b, alpha or 1) end
	end
	return edges
end

local function Label(parent, size, col, text)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(Font(), size or 12, "")
	col = col or TEXT
	fs:SetTextColor(col[1], col[2], col[3])
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	if text then fs:SetText(text) end
	return fs
end

-------------------------------------------------------------------------------
-- widgets
-------------------------------------------------------------------------------
local function Toggle(parent, get, set)
	local f = CreateFrame("Button", nil, parent)
	f:SetSize(32, 16)
	f.track = Fill(f, { 0.27, 0.26, 0.30 })
	Border(f)
	f.knob = Tex(f, "ARTWORK", { 0.97, 0.97, 0.99 })
	f.knob:SetSize(12, 12)
	function f:Refresh()
		self.on = get() and true or false
		self.knob:ClearAllPoints()
		if self.on then
			self.track:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3])
			self.knob:SetPoint("RIGHT", -2, 0)
		else
			self.track:SetVertexColor(0.27, 0.26, 0.30)
			self.knob:SetPoint("LEFT", 2, 0)
		end
	end
	f:SetScript("OnClick", function(self)
		set(not self.on)
		self:Refresh()
		if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
	end)
	f:Refresh()
	return f
end

local function Slider(parent, min, max, step, get, set)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(210, 18)
	local s = CreateFrame("Slider", nil, f)
	s:SetOrientation("HORIZONTAL")
	s:SetPoint("LEFT"); s:SetPoint("RIGHT", -44, 0)
	s:SetHeight(14)
	s:SetMinMaxValues(min, max)
	s:SetValueStep(step)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	local track = Tex(s, "BACKGROUND", { 0.30, 0.29, 0.34 })
	track:SetHeight(3); track:SetPoint("LEFT"); track:SetPoint("RIGHT")
	local fill = Tex(s, "BORDER", ACCENT)
	fill:SetHeight(3); fill:SetPoint("LEFT")
	local thumb = s:CreateTexture(nil, "OVERLAY")
	thumb:SetTexture(FLAT)
	thumb:SetVertexColor(0.95, 0.95, 0.97)
	thumb:SetSize(8, 14)
	s:SetThumbTexture(thumb)
	local val = Label(f, 12, TEXT)
	val:SetPoint("RIGHT", 0, 0)
	local busy = false
	local function Paint(v)
		local w = s:GetWidth()
		if w and w > 0 then fill:SetWidth(math.max(1, (v - min) / (max - min) * w)) end
		val:SetText(tostring(v))
	end
	function f:Refresh()
		busy = true
		local v = get()
		s:SetValue(v)
		Paint(v)
		busy = false
	end
	s:SetScript("OnValueChanged", function(_, v)
		v = math.floor(v / step + 0.5) * step
		Paint(v)
		if not busy then set(v) end
	end)
	s:SetScript("OnSizeChanged", function() Paint(math.floor(s:GetValue() / step + 0.5) * step) end)
	s:EnableMouseWheel(true)
	s:SetScript("OnMouseWheel", function(_, d)
		s:SetValue(math.min(max, math.max(min, s:GetValue() + d * step)))
	end)
	f:Refresh()
	return f
end

local function Button(parent, text, onClick, width)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 120, 24)
	Fill(b, { 0.26, 0.20, 0.32 })
	Border(b)
	b.text = Label(b, 12, TEXT, text)
	b.text:SetPoint("CENTER")
	b:SetScript("OnEnter", function(self) self.fill:SetVertexColor(ACCENT[1] * 0.7, ACCENT[2] * 0.7, ACCENT[3] * 0.7) end)
	b:SetScript("OnLeave", function(self) self.fill:SetVertexColor(0.26, 0.20, 0.32) end)
	b:SetScript("OnClick", function(self) onClick(self) end)
	return b
end

-------------------------------------------------------------------------------
-- drag-to-move boxes
-------------------------------------------------------------------------------
local AREAS = {
	{ key = "Incoming", label = "Incoming", hint = "damage & heals you take" },
	{ key = "Outgoing", label = "Outgoing", hint = "your hits & heals" },
	{ key = "Notification", label = "Notifications", hint = "loot, power, buffs" },
}
local movers, moverBar = {}, nil
UI.unlocked = false

local function AreaDB(key)
	local sa = NS("ScrollAreas")
	return sa and sa.areas and sa.areas[key]
end

local function AlignOf(a)
	local _, align = (";"):split(a.direction or "DOWN;CENTER")
	if align == "LEFT" or align == "RIGHT" then return align end
	return "CENTER"
end

local MOVER_W = 170
local MIN_W, MIN_H, MAX_W, MAX_H = 80, 40, 700, 700

local function PlaceMover(m)
	local a = AreaDB(m.key)
	if not a then m:Hide() return end
	m:SetSize(a.boxWidth or MOVER_W, math.max(MIN_H, a.size or 150))
	m:ClearAllPoints()
	m:SetPoint(AlignOf(a), UIParent, "CENTER", a.xOffset or 0, a.yOffset or 0)
	m.coords:SetText(("%d, %d  ·  %d tall"):format(a.xOffset or 0, a.yOffset or 0, a.size or 150))
end

local function SaveMover(m)
	local a = AreaDB(m.key)
	if not a then return end
	local ux, uy = UIParent:GetCenter()
	local align = AlignOf(a)
	local x
	if align == "LEFT" then x = m:GetLeft()
	elseif align == "RIGHT" then x = m:GetRight()
	else x = (m:GetLeft() + m:GetRight()) / 2 end
	local _, cy = m:GetCenter()
	a.xOffset = math.floor(x - ux + 0.5)
	a.yOffset = math.floor(cy - uy + 0.5)
	-- the box's height is how far the text scrolls; its width marks the lane
	a.size = math.floor(math.max(MIN_H, math.min(MAX_H, m:GetHeight())) + 0.5)
	a.boxWidth = math.floor(math.max(MIN_W, math.min(MAX_W, m:GetWidth())) + 0.5)
	PlaceMover(m)
end

local function MakeMover(info)
	local m = CreateFrame("Frame", nil, UIParent)
	m.key = info.key
	m:SetFrameStrata("DIALOG")
	m:SetMovable(true)
	m:EnableMouse(true)
	m:RegisterForDrag("LeftButton")
	m:SetClampedToScreen(true)
	Fill(m, BG, 0.75)
	Border(m, ACCENT, 1)
	local bar = Tex(m, "ARTWORK", ACCENT, 1)
	bar:SetHeight(3); bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
	m.title = Label(m, 14, TEXT, info.label)
	m.title:SetPoint("TOP", 0, -8)
	m.hint = Label(m, 11, MUTED, info.hint)
	m.hint:SetPoint("TOP", m.title, "BOTTOM", 0, -3)
	m.coords = Label(m, 10, MUTED, "")
	m.coords:SetPoint("BOTTOM", 0, 6)
	m:SetResizable(true)
	if m.SetResizeBounds then
		m:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
	elseif m.SetMinResize then
		m:SetMinResize(MIN_W, MIN_H); m:SetMaxResize(MAX_W, MAX_H)
	end
	-- resize grip, bottom right corner
	local grip = CreateFrame("Button", nil, m)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -2, 2)
	grip:SetFrameLevel(m:GetFrameLevel() + 5)
	for i = 1, 3 do
		local t = Tex(grip, "OVERLAY", ACCENT, 1)
		t:SetSize(i * 4, 2)
		t:SetPoint("BOTTOMRIGHT", 0, (i - 1) * 4)
	end
	grip:SetScript("OnMouseDown", function() m:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function()
		m:StopMovingOrSizing()
		SaveMover(m)
	end)
	grip:SetScript("OnEnter", function() m:SetBorderColor(1, 1, 1) end)
	grip:SetScript("OnLeave", function() m:SetBorderColor(ACCENT[1], ACCENT[2], ACCENT[3]) end)
	m:SetScript("OnSizeChanged", function(self, w, h)
		self.coords:SetText(("%d tall"):format(h or 0))
	end)
	m:SetScript("OnDragStart", function(self) self:StartMoving() end)
	m:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SaveMover(self)
	end)
	m:SetScript("OnEnter", function(self) self:SetBorderColor(1, 1, 1) end)
	m:SetScript("OnLeave", function(self) self:SetBorderColor(ACCENT[1], ACCENT[2], ACCENT[3]) end)
	m:Hide()
	return m
end

local function MakeMoverBar()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetFrameStrata("DIALOG")
	f:SetSize(360, 64)
	f:SetPoint("TOP", 0, -120)
	Fill(f, PANEL, 0.95)
	Border(f)
	local t = Label(f, 13, TEXT)
	t:SetText("|cffff4fa3Gram|r Combat  ·  drag to move  ·  corner to resize")
	t:SetPoint("TOP", 0, -10)
	local lock = Button(f, "Lock", function() UI:Lock() end, 100)
	lock:SetPoint("BOTTOMRIGHT", -10, 8)
	local test = Button(f, "Test", function() if ns.TestFeed then ns.TestFeed() end end, 100)
	test:SetPoint("RIGHT", lock, "LEFT", -6, 0)
	local reset = Button(f, "Reset", function() UI:ResetPositions() end, 100)
	reset:SetPoint("RIGHT", test, "LEFT", -6, 0)
	f:Hide()
	return f
end

function UI:Unlock()
	if InCombatLockdown and InCombatLockdown() then
		print("|cffff4fa3Gram Combat|r leave combat first, then unlock.")
		return
	end
	if #movers == 0 then
		for _, info in ipairs(AREAS) do movers[#movers + 1] = MakeMover(info) end
		moverBar = MakeMoverBar()
	end
	for _, m in ipairs(movers) do PlaceMover(m); m:Show() end
	moverBar:Show()
	self.unlocked = true
	if self.frame and self.frame.Refresh then self.frame:Refresh() end
end

function UI:Lock()
	for _, m in ipairs(movers) do m:Hide() end
	if moverBar then moverBar:Hide() end
	self.unlocked = false
	if self.frame and self.frame.Refresh then self.frame:Refresh() end
end

function UI:ToggleLock()
	if self.unlocked then self:Lock() else self:Unlock() end
end

function UI:ResetPositions()
	local layout = ns.GramLayout and ns.GramLayout()
	local sa = NS("ScrollAreas")
	if not (layout and sa and sa.areas) then return end
	for name, v in next, layout do
		sa.areas[name] = sa.areas[name] or {}
		for k, val in next, v do sa.areas[name][k] = val end
	end
	for _, m in ipairs(movers) do if m:IsShown() then PlaceMover(m) end end
end

-------------------------------------------------------------------------------
-- settings panel
-------------------------------------------------------------------------------
local function Forever() return Parrot() and Parrot().foreverDB and Parrot().foreverDB.profile end

local function EventEnabled(category, ...)
	local ce = NS("CombatEvents")
	if not ce then return true end
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		local e = ce[category] and ce[category][name]
		if e and e.disabled then return false end
	end
	return true
end

local function SetEvents(category, on, ...)
	local ce = NS("CombatEvents")
	if not ce then return end
	ce[category] = ce[category] or {}
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		ce[category][name] = ce[category][name] or {}
		ce[category][name].disabled = not on
	end
end

local function Build()
	local f = CreateFrame("Frame", "GramCombatPanel", UIParent)
	f:SetSize(560, 590)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	Fill(f, BG, 0.97)
	Border(f)
	tinsert(UISpecialFrames, "GramCombatPanel") -- Escape closes it

	-- header
	local head = CreateFrame("Frame", nil, f)
	head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT"); head:SetHeight(48)
	Fill(head, PANEL, 1)
	local accent = Tex(head, "ARTWORK", ACCENT, 1)
	accent:SetHeight(2); accent:SetPoint("BOTTOMLEFT"); accent:SetPoint("BOTTOMRIGHT")
	head:EnableMouse(true)
	head:RegisterForDrag("LeftButton")
	head:SetScript("OnDragStart", function() f:StartMoving() end)
	head:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
	local logo = head:CreateTexture(nil, "ARTWORK")
	logo:SetTexture("Interface\\AddOns\\GramCombat\\Media\\icon")
	logo:SetSize(30, 30)
	logo:SetPoint("LEFT", 12, 0)
	local title = Label(head, 20, TEXT, "|cffff4fa3Gram|r Combat")
	title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
	local ver = Label(head, 11, MUTED, "v" .. ((C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("GramCombat", "Version")) or ""))
	ver:SetPoint("LEFT", title, "RIGHT", 8, -2)
	local close = Button(head, "X", function() f:Hide() end, 28)
	close:SetPoint("RIGHT", -10, 0)

	local refreshers = {}
	local y = -64
	local function Section(text)
		local s = Label(f, 13, ACCENT, text:upper())
		s:SetPoint("TOPLEFT", 20, y)
		local line = Tex(f, "ARTWORK", { 1, 1, 1 }, 0.08)
		line:SetHeight(1)
		line:SetPoint("LEFT", s, "RIGHT", 10, 0)
		line:SetPoint("RIGHT", f, "RIGHT", -20, 0)
		y = y - 26
	end
	local col = 0
	local function Row(label, widget, help)
		local x = col == 0 and 20 or 290
		local l = Label(f, 12, TEXT, label)
		l:SetPoint("TOPLEFT", x, y)
		widget:SetPoint("TOPLEFT", x + 160, y + 1)
		if widget.Refresh then refreshers[#refreshers + 1] = widget end
		if help then
			l:EnableMouse(true)
		end
		if col == 0 then col = 1 else col = 0; y = y - 30 end
	end
	local function EndRows() if col == 1 then col = 0; y = y - 30 end end
	local function WideRow(label, widget)
		EndRows()
		local l = Label(f, 12, TEXT, label)
		l:SetPoint("TOPLEFT", 20, y)
		widget:SetPoint("TOPLEFT", 180, y + 1)
		if widget.Refresh then refreshers[#refreshers + 1] = widget end
		y = y - 30
	end

	-- POSITION
	Section("Position")
	local unlock = Button(f, "Unlock & Move", function() UI:ToggleLock() end, 160)
	unlock:SetPoint("TOPLEFT", 20, y)
	local test = Button(f, "Test", function() if ns.TestFeed then ns.TestFeed() end end, 110)
	test:SetPoint("LEFT", unlock, "RIGHT", 8, 0)
	local reset = Button(f, "Reset Positions", function() UI:ResetPositions() end, 140)
	reset:SetPoint("LEFT", test, "RIGHT", 8, 0)
	y = y - 40

	-- SHOW
	Section("Show")
	local fdb = function(k) return function() local d = Forever(); return d and d[k] end end
	local fset = function(k) return function(v) local d = Forever(); if d then d[k] = v end end end
	Row("Damage Taken", Toggle(f, fdb("incoming"), fset("incoming")))
	Row("Your Damage", Toggle(f, fdb("outgoing"), fset("outgoing")))
	Row("Heals", Toggle(f, fdb("heals"), fset("heals")))
	local MISSES = {}
	for _, t in ipairs({ "absorbs", "blocks", "dodges", "evades", "immunes", "misses", "parries", "reflects", "resists", "deflects" }) do
		MISSES[#MISSES + 1] = "Melee " .. t
		MISSES[#MISSES + 1] = "Skill " .. t
	end
	Row("Dodge / Parry / Miss", Toggle(f,
		function() return EventEnabled("Incoming", "Melee dodges") end,
		function(v) SetEvents("Incoming", v, unpack(MISSES)); SetEvents("Outgoing", v, unpack(MISSES)) end))
	Row("Loot & Money", Toggle(f,
		function() return EventEnabled("Notification", "Loot items", "Loot money") end,
		function(v) SetEvents("Notification", v, "Loot items", "Loot money") end))
	Row("Buffs & Debuffs", Toggle(f, fdb("auras"), fset("auras")))
	Row("Combat In / Out", Toggle(f,
		function() return EventEnabled("Notification", "Enter combat", "Leave combat") end,
		function(v) SetEvents("Notification", v, "Enter combat", "Leave combat") end))
	Row("XP, Rep & Honor", Toggle(f,
		function() return EventEnabled("Notification", "Experience gains", "Reputation gains", "Currency gains") end,
		function(v) SetEvents("Notification", v, "Experience gains", "Reputation gains", "Reputation losses", "Currency gains", "Skill gains") end))
	Row("Blizzard's Numbers", Toggle(f,
		function()
			local ok, v = pcall(GetCVar, "floatingCombatTextCombatDamage")
			return not ok or v ~= "0"
		end,
		function(v)
			pcall(SetCVar, "floatingCombatTextCombatDamage", v and "1" or "0")
			pcall(SetCVar, "floatingCombatTextCombatHealing", v and "1" or "0")
		end))
	EndRows()
	y = y - 6

	-- TEXT
	Section("Text")
	local disp = function(k) return function() local d = NS("Display"); return d and d[k] or 14 end end
	local dset = function(k) return function(v) local d = NS("Display"); if d then d[k] = v end end end
	WideRow("Text Size", Slider(f, 8, 32, 1, disp("fontSize"), dset("fontSize")))
	WideRow("Crit Size", Slider(f, 10, 40, 1, disp("stickyFontSize"), dset("stickyFontSize")))
	Row("Spell Icons", Toggle(f,
		function() local d = NS("Display"); return not d or d.iconsEnabled ~= false end,
		function(v) local d = NS("Display"); if d then d.iconsEnabled = v end end))
	Row("Spell Names", Toggle(f, fdb("spellNames"), fset("spellNames")))
	EndRows()
	y = y - 6

	-- FOREVER
	Section("Groups")
	Row("Guess In Groups", Toggle(f, fdb("groupGuess"), fset("groupGuess")))
	EndRows()
	local note = Label(f, 11, MUTED,
		"In a group, auto attacks and DoT ticks can't be told apart from your group's, so they stay hidden unless this is on. Solo, everything on your mob counts as yours.")
	note:SetPoint("TOPLEFT", 20, y + 4)
	note:SetWidth(520)
	note:SetJustifyH("LEFT")
	note:SetWordWrap(true)

	-- footer
	local adv = Button(f, "Advanced Settings", function()
		f:Hide()
		if Parrot() then Parrot():ShowAdvanced() end
	end, 160)
	adv:SetPoint("BOTTOMLEFT", 20, 16)
	local foot = Label(f, 11, MUTED, "/gc  ·  /gc move  ·  /gc test")
	foot:SetPoint("BOTTOMRIGHT", -20, 22)

	function f:Refresh()
		for _, w in ipairs(refreshers) do w:Refresh() end
		unlock.text:SetText(UI.unlocked and "Lock" or "Unlock & Move")
	end
	f:SetScript("OnShow", function(self) self:Refresh() end)
	f:Hide()
	return f
end

function UI:Toggle()
	self.frame = self.frame or Build()
	if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

function UI:Open()
	self.frame = self.frame or Build()
	self.frame:Show()
end
