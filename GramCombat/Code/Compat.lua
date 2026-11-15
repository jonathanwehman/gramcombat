-- Gram Combat: compatibility layer for WoW Forever (Midnight-era client).
-- Old-style API calls are rebuilt on the modern C_ namespaces here and handed
-- to the other files as locals, so nothing global is replaced.
local _, ns = ...

local C = {}
ns.C = C

local issecretvalue = issecretvalue
local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end
C.IsSecret = IsSecret

-- returns v, or nil when the client hands back a hidden (secret) value
local function Plain(v)
	if IsSecret(v) then return nil end
	return v
end
C.Plain = Plain

-- Combat log flag constants (kept by the client today, but don't count on it)
local flags = {
	COMBATLOG_OBJECT_AFFILIATION_MINE = 0x00000001,
	COMBATLOG_OBJECT_AFFILIATION_PARTY = 0x00000002,
	COMBATLOG_OBJECT_AFFILIATION_RAID = 0x00000004,
	COMBATLOG_OBJECT_AFFILIATION_OUTSIDER = 0x00000008,
	COMBATLOG_OBJECT_REACTION_FRIENDLY = 0x00000010,
	COMBATLOG_OBJECT_REACTION_NEUTRAL = 0x00000020,
	COMBATLOG_OBJECT_REACTION_HOSTILE = 0x00000040,
	COMBATLOG_OBJECT_CONTROL_PLAYER = 0x00000100,
	COMBATLOG_OBJECT_CONTROL_NPC = 0x00000200,
	COMBATLOG_OBJECT_TYPE_PLAYER = 0x00000400,
	COMBATLOG_OBJECT_TYPE_NPC = 0x00000800,
	COMBATLOG_OBJECT_TYPE_PET = 0x00001000,
	COMBATLOG_OBJECT_TYPE_GUARDIAN = 0x00002000,
	COMBATLOG_OBJECT_TYPE_OBJECT = 0x00004000,
}
for k, v in pairs(flags) do
	if type(rawget(_G, k)) ~= "number" then _G[k] = v end
end

-- Spells ---------------------------------------------------------------------
function C.GetSpellInfo(spell)
	if spell == nil then return nil end
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = pcall(C_Spell.GetSpellInfo, spell)
		if ok and type(info) == "table" then
			return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID, info.originalIconID
		end
		return nil
	end
	if _G.GetSpellInfo then return _G.GetSpellInfo(spell) end
end

function C.GetSpellTexture(spell)
	if spell == nil then return nil end
	if C_Spell and C_Spell.GetSpellTexture then
		local ok, tex = pcall(C_Spell.GetSpellTexture, spell)
		if ok then return Plain(tex) end
		return nil
	end
	if _G.GetSpellTexture then return _G.GetSpellTexture(spell) end
end

local BANK_PLAYER = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0

-- GetSpellCooldown(spell) or GetSpellCooldown(slot, "spell").
-- Hidden values come back as nil, so callers never compare a secret.
function C.GetSpellCooldown(spell, book)
	local info
	if book and C_SpellBook and C_SpellBook.GetSpellBookItemCooldown then
		local ok, r = pcall(C_SpellBook.GetSpellBookItemCooldown, spell, BANK_PLAYER)
		if ok then info = r end
	elseif C_Spell and C_Spell.GetSpellCooldown then
		local ok, r = pcall(C_Spell.GetSpellCooldown, spell)
		if ok then info = r end
	elseif _G.GetSpellCooldown then
		return _G.GetSpellCooldown(spell, book)
	end
	if type(info) ~= "table" then return nil end
	local start, duration = Plain(info.startTime), Plain(info.duration)
	if start == nil or duration == nil then return nil end
	return start, duration, info.isEnabled, info.modRate
end

function C.IsUsableSpell(spell)
	if C_Spell and C_Spell.IsSpellUsable then
		local ok, usable, noMana = pcall(C_Spell.IsSpellUsable, spell)
		if ok then return Plain(usable), Plain(noMana) end
		return nil
	end
	if _G.IsUsableSpell then return _G.IsUsableSpell(spell) end
end

function C.GetNumSpellTabs()
	if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
		return C_SpellBook.GetNumSpellBookSkillLines() or 0
	end
	if _G.GetNumSpellTabs then return _G.GetNumSpellTabs() end
	return 0
end

function C.GetSpellTabInfo(tab)
	if C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo then
		local info = C_SpellBook.GetSpellBookSkillLineInfo(tab)
		if info then
			return info.name, info.iconID, info.itemIndexOffset or 0, info.numSpellBookItems or 0
		end
		return nil, nil, 0, 0
	end
	if _G.GetSpellTabInfo then return _G.GetSpellTabInfo(tab) end
	return nil, nil, 0, 0
end

function C.GetSpellBookItemName(index)
	if C_SpellBook and C_SpellBook.GetSpellBookItemName then
		return C_SpellBook.GetSpellBookItemName(index, BANK_PLAYER)
	end
	if _G.GetSpellBookItemName then return _G.GetSpellBookItemName(index, "spell") end
end

function C.IsSpellHarmful(spellID)
	if C_Spell and C_Spell.IsSpellHarmful then
		local ok, r = pcall(C_Spell.IsSpellHarmful, spellID)
		if ok then return Plain(r) end
	end
	return nil
end

function C.IsSpellHelpful(spellID)
	if C_Spell and C_Spell.IsSpellHelpful then
		local ok, r = pcall(C_Spell.IsSpellHelpful, spellID)
		if ok then return Plain(r) end
	end
	return nil
end

-- Items ----------------------------------------------------------------------
function C.GetItemInfo(item)
	if item == nil then return nil end
	if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(item) end
	if _G.GetItemInfo then return _G.GetItemInfo(item) end
end

function C.GetItemIcon(item)
	if item == nil then return nil end
	if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(item) end
	if _G.GetItemIcon then return _G.GetItemIcon(item) end
end

function C.GetItemCount(item, ...)
	if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(item, ...) or 0 end
	if _G.GetItemCount then return _G.GetItemCount(item, ...) or 0 end
	return 0
end

function C.ItemQualityColor(quality)
	local colors = _G.ITEM_QUALITY_COLORS
	if colors and quality and colors[quality] then return colors[quality] end
	if quality and C_Item and C_Item.GetItemQualityColor then
		local r, g, b, hex = C_Item.GetItemQualityColor(quality)
		if hex then return { hex = "|c" .. hex } end
	end
end

function C.BreakUpLargeNumbers(n)
	if _G.BreakUpLargeNumbers then return _G.BreakUpLargeNumbers(n) end
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function C.UnitInVehicle(unit)
	if _G.UnitInVehicle then return _G.UnitInVehicle(unit) end
	return false
end

function C.GetSchoolString(school)
	if C_Spell and C_Spell.GetSchoolString then
		local ok, s = pcall(C_Spell.GetSchoolString, school)
		if ok then return Plain(s) end
	end
	if _G.GetSchoolString then return _G.GetSchoolString(school) end
end

-- Addons ---------------------------------------------------------------------
C.LoadAddOn = (C_AddOns and C_AddOns.LoadAddOn) or _G.LoadAddOn
C.GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata

-- Calls f(...) and swallows errors caused by hidden (secret) values only;
-- every other error still reaches the normal error handler.
function C.SafeCall(f, ...)
	local ok, err = pcall(f, ...)
	if not ok and type(err) == "string" and not err:find("secret") then
		geterrorhandler()(err)
	end
	return ok
end
