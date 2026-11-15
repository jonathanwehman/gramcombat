-- Gram Combat: the Forever combat feed.
--
-- WoW Forever doesn't let addons read the combat log. What it does give us:
--   UNIT_COMBAT              a unit took damage / healing / dodged, with amount,
--                            school and crit flag, but not who did it or with what
--   UNIT_SPELLCAST_SENT/     your own casts (spell + target name)
--   UNIT_SPELLCAST_SUCCEEDED
--   UNIT_AURA                aura changes (hidden in combat in some places)
--
-- This file rebuilds combat-log style events from those and hands them to the
-- rest of the addon exactly like the old combat log did, so every event, tag,
-- throttle and trigger keeps working.
--
-- Who did it: your hits are matched to your own casts by timing and target.
-- Anything unmatched is only counted as yours when you're solo (or when the
-- "Guess in groups" option is on).
local _, ns = ...
local C = ns.C
local Plain, IsSecret = C.Plain, C.IsSecret

local GetTime, UnitGUID, UnitName, UnitExists = GetTime, UnitGUID, UnitName, UnitExists
local bit_bor = bit.bor
local pcall, type, next, wipe = pcall, type, next, wipe

local Feed = CreateFrame("Frame")
ns.Feed = Feed

-------------------------------------------------------------------------------
-- Dispatch
-------------------------------------------------------------------------------
local handlers = {}
local nextUID -- set by Parrot.lua

function ns.SetCombatLogHandlers(t, uidFunc)
	handlers = t
	nextUID = uidFunc
end

local function Emit(eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	if not next(handlers) then return end
	local uid = nextUID and nextUID() or 0
	local ts = GetTime()
	for mod in next, handlers do
		C.SafeCall(mod.HandleCombatlogEvent, mod, uid, ts, eventType, false,
			srcGUID or "", srcName or "", srcFlags or 0, 0,
			dstGUID or "", dstName or "", dstFlags or 0, 0, ...)
	end
end
ns.FeedEmit = Emit

-------------------------------------------------------------------------------
-- Settings (stored by Parrot.lua in the "Forever" namespace)
-------------------------------------------------------------------------------
local settings = { groupGuess = false, auras = true, incoming = true, outgoing = true, heals = true, spellNames = false }
function ns.SetFeedSettings(t) settings = t end

-------------------------------------------------------------------------------
-- Unit helpers
-------------------------------------------------------------------------------
local F = {
	MINE = COMBATLOG_OBJECT_AFFILIATION_MINE,
	PARTY = COMBATLOG_OBJECT_AFFILIATION_PARTY,
	RAID = COMBATLOG_OBJECT_AFFILIATION_RAID,
	OUTSIDER = COMBATLOG_OBJECT_AFFILIATION_OUTSIDER,
	FRIENDLY = COMBATLOG_OBJECT_REACTION_FRIENDLY,
	NEUTRAL = COMBATLOG_OBJECT_REACTION_NEUTRAL,
	HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE,
	CPLAYER = COMBATLOG_OBJECT_CONTROL_PLAYER,
	CNPC = COMBATLOG_OBJECT_CONTROL_NPC,
	TPLAYER = COMBATLOG_OBJECT_TYPE_PLAYER,
	TNPC = COMBATLOG_OBJECT_TYPE_NPC,
	TPET = COMBATLOG_OBJECT_TYPE_PET,
}
local FLAGS_ME = bit_bor(F.MINE, F.FRIENDLY, F.CPLAYER, F.TPLAYER)
local FLAGS_PET = bit_bor(F.MINE, F.FRIENDLY, F.CPLAYER, F.TPET)
local FLAGS_UNKNOWN_ENEMY = bit_bor(F.OUTSIDER, F.HOSTILE, F.CNPC, F.TNPC)

local playerGUID, playerName

local function call(f, ...)
	local ok, a, b = pcall(f, ...)
	if ok then return Plain(a), Plain(b) end
end

local function UnitInfo(unit)
	if unit == "player" then return playerGUID, playerName, FLAGS_ME end
	local guid = call(UnitGUID, unit)
	local name = call(UnitName, unit)
	if unit == "pet" then return guid or "", name or "", FLAGS_PET end
	local flags
	local isPlayer = call(UnitIsPlayer, unit)
	local hostile = call(UnitCanAttack, "player", unit)
	if hostile then
		flags = bit_bor(F.OUTSIDER, F.HOSTILE, isPlayer and F.CPLAYER or F.CNPC, isPlayer and F.TPLAYER or F.TNPC)
	else
		local inParty = call(UnitInParty, unit)
		local inRaid = call(UnitInRaid, unit)
		flags = bit_bor(inRaid and F.RAID or (inParty and F.PARTY or F.OUTSIDER), F.FRIENDLY,
			isPlayer and F.CPLAYER or F.CNPC, isPlayer and F.TPLAYER or F.TNPC)
	end
	return guid or "", name or "", flags, hostile
end

local SCHOOL_NAMES = {
	[1] = STRING_SCHOOL_PHYSICAL, [2] = STRING_SCHOOL_HOLY, [4] = STRING_SCHOOL_FIRE,
	[8] = STRING_SCHOOL_NATURE, [16] = STRING_SCHOOL_FROST, [32] = STRING_SCHOOL_SHADOW,
	[64] = STRING_SCHOOL_ARCANE,
}
local function SchoolName(school)
	return SCHOOL_NAMES[school] or (school and school > 0 and C.GetSchoolString(school)) or nil
end

-------------------------------------------------------------------------------
-- Own casts
-------------------------------------------------------------------------------
local casts = {}         -- newest last: { t, id, name, harmful, helpful, ranged, target, hit = {} }
local sentTargets = {}   -- castGUID -> target name from UNIT_SPELLCAST_SENT
local MAX_CASTS = 12

local function OnCastSent(unit, target, castGUID)
	if unit ~= "player" then return end
	castGUID = Plain(castGUID)
	if castGUID then sentTargets[castGUID] = Plain(target) or "" end
end

local function OnCastSucceeded(unit, castGUID, spellID)
	if unit ~= "player" then return end
	spellID = Plain(spellID)
	if not spellID then return end
	local name, _, _, _, _, maxRange = C.GetSpellInfo(spellID)
	if not name then return end
	castGUID = Plain(castGUID)
	local target = castGUID and sentTargets[castGUID]
	if castGUID then sentTargets[castGUID] = nil end
	casts[#casts + 1] = {
		t = GetTime(), id = spellID, name = name,
		harmful = C.IsSpellHarmful(spellID), helpful = C.IsSpellHelpful(spellID),
		ranged = (Plain(maxRange) or 0) > 8,
		target = target, hit = {},
	}
	if #casts > MAX_CASTS then table.remove(casts, 1) end
end

-- kind: "harm" or "help"; key: unit key (name/guid); unitName for target match
local function MatchCast(kind, key, unitName, physical)
	local now = GetTime()
	for i = #casts, 1, -1 do
		local c = casts[i]
		local age = now - c.t
		if age > 1.6 then break end
		local okKind
		if kind == "harm" then
			okKind = c.harmful ~= false and c.helpful ~= true
		else
			okKind = c.helpful ~= false and c.harmful ~= true
		end
		local window
		if kind == "help" then window = 0.6
		elseif physical and not c.ranged then window = 0.35
		else window = 1.6 end
		local okTarget = (not c.target) or c.target == "" or not unitName or unitName == ""
			or c.target == unitName or c.target:match("^[^-]+") == unitName:match("^[^-]+")
		if okKind and age <= window and okTarget and not c.hit[key] then
			c.hit[key] = true
			return c
		end
	end
end

-------------------------------------------------------------------------------
-- UNIT_COMBAT
-------------------------------------------------------------------------------
local MISS_ACTIONS = {
	DODGE = true, PARRY = true, MISS = true, BLOCK = true, RESIST = true, IMMUNE = true,
	EVADE = true, DEFLECT = true, REFLECT = true, ABSORB = true,
}

local friendlyTokens = { target = true, focus = true }
for i = 1, 4 do friendlyTokens["party" .. i] = true end
for i = 1, 40 do friendlyTokens["raid" .. i] = true end

local function IsHostileToken(unit)
	return unit == "target" or unit == "focus" or unit == "softenemy"
		or unit:match("^nameplate%d+$") or unit:match("^boss%d$")
end

-- the same hit arrives once per unit token (target + nameplate3 + ...)
local seen, seenTime = {}, 0
local function Seen(key)
	local now = GetTime()
	if now ~= seenTime then wipe(seen); seenTime = now end
	if seen[key] then return true end
	seen[key] = true
end

local function Solo()
	return not IsInGroup()
end

-- Hidden (secret) amounts can't be read, so they skip the normal text system
-- and go straight to the screen through SecretText.lua.
local function SecretKey(...)
	-- dedupe key without the hidden amount
	return table.concat({ ... }, "|")
end

local function OnSecretHit(unit, action, isCrit, school, rawAmount)
	local Secret = ns.Secret
	if not Secret then return end
	local color = Secret.SchoolColor(school)
	local physical = school == 1

	if unit == "player" then
		if Seen(SecretKey("player", action, school, isCrit and 1 or 0)) then return end
		if action == "WOUND" then
			if not settings.incoming then return end
			Secret:Show("Incoming", "-%s", rawAmount, { color = physical and "ff4d4d" or color, crit = isCrit })
		elseif action == "HEAL" then
			if not settings.heals then return end
			local c = MatchCast("help", "player", playerName)
			Secret:Show("Incoming", "+%s", rawAmount, { color = "4dff4d", crit = isCrit,
				icon = c and C.GetSpellTexture(c.id) or nil })
		end
		return
	end
	if unit == "pet" then return end

	local guid, name, _, hostile = UnitInfo(unit)
	if call(UnitIsUnit, unit, "player") then return end
	local key = (guid ~= "" and guid) or name
	if key == "" then key = unit end

	if hostile and IsHostileToken(unit) and action == "WOUND" then
		if not settings.outgoing then return end
		if Seen(SecretKey(key, action, school, isCrit and 1 or 0)) then return end
		local c = MatchCast("harm", key, name, physical)
		if not c then
			if call(UnitIsTapDenied, unit) then return end
			if not (Solo() or settings.groupGuess) then return end
		end
		local fmt = "%s"
		if c and settings.spellNames then fmt = "%s " .. c.name end
		if isCrit then fmt = fmt .. "!" end
		Secret:Show("Outgoing", fmt, rawAmount, { color = color, crit = isCrit,
			icon = c and C.GetSpellTexture(c.id) or nil })
	elseif not hostile and action == "HEAL" and friendlyTokens[unit] then
		if not settings.heals then return end
		if Seen(SecretKey(key, "HEAL", school)) then return end
		local c = MatchCast("help", key, name)
		if c then
			Secret:Show("Outgoing", "+%s", rawAmount, { color = "4dff4d", crit = isCrit,
				icon = C.GetSpellTexture(c.id) })
		end
	end
end

local function OnUnitCombat(unit, action, flagText, amount, school)
	if type(unit) ~= "string" then return end
	action = Plain(action)
	if not action then return end
	flagText = Plain(flagText) or ""
	school = Plain(school) or 1
	if amount ~= nil and IsSecret(amount) then
		OnSecretHit(unit, action, flagText == "CRITICAL", school, amount)
		return
	end
	amount = Plain(amount)
	-- show / hide switches from the Gram Combat panel
	if unit == "player" then
		if action == "WOUND" and not settings.incoming then return end
		if action == "HEAL" and not settings.heals then return end
	elseif unit ~= "pet" then
		if action == "HEAL" and not settings.heals then return end
		if action ~= "HEAL" and not settings.outgoing then return end
	end
	local isCrit = flagText == "CRITICAL"
	local isCrushing = flagText == "CRUSHING"
	local isGlancing = flagText == "GLANCING"
	local physical = school == 1

	-------------------------------------------------------------- incoming
	if unit == "player" then
		if Seen("player" .. action .. tostring(amount)) then return end
		if action == "WOUND" and amount and amount > 0 then
			if physical then
				Emit("SWING_DAMAGE", "", "", FLAGS_UNKNOWN_ENEMY, playerGUID, playerName, FLAGS_ME,
					amount, -1, school, nil, nil, nil, isCrit, isGlancing, isCrushing, false)
			else
				Emit("SPELL_DAMAGE", "", "", FLAGS_UNKNOWN_ENEMY, playerGUID, playerName, FLAGS_ME,
					nil, SchoolName(school), school, amount, -1, school, nil, nil, nil, isCrit, isGlancing, isCrushing, false)
			end
		elseif action == "HEAL" and amount and amount > 0 then
			local c = MatchCast("help", "player", playerName)
			if c then
				Emit("SPELL_HEAL", playerGUID, playerName, FLAGS_ME, playerGUID, playerName, FLAGS_ME,
					c.id, c.name, school, amount, 0, 0, isCrit)
			else
				Emit("SPELL_HEAL", "", "", 0, playerGUID, playerName, FLAGS_ME,
					nil, SchoolName(school) or "", school, amount, 0, 0, isCrit)
			end
		elseif MISS_ACTIONS[action] then
			Emit("SWING_MISSED", "", "", FLAGS_UNKNOWN_ENEMY, playerGUID, playerName, FLAGS_ME,
				action, false, amount)
		end
		return
	end

	-------------------------------------------------------------- pet
	if unit == "pet" then
		local guid, name = UnitInfo("pet")
		if Seen("pet" .. action .. tostring(amount)) then return end
		if action == "WOUND" and amount and amount > 0 then
			if physical then
				Emit("SWING_DAMAGE", "", "", FLAGS_UNKNOWN_ENEMY, guid, name, FLAGS_PET,
					amount, -1, school, nil, nil, nil, isCrit, isGlancing, isCrushing, false)
			else
				Emit("SPELL_DAMAGE", "", "", FLAGS_UNKNOWN_ENEMY, guid, name, FLAGS_PET,
					nil, SchoolName(school), school, amount, -1, school, nil, nil, nil, isCrit, isGlancing, isCrushing, false)
			end
		elseif action == "HEAL" and amount and amount > 0 then
			Emit("SPELL_HEAL", "", "", 0, guid, name, FLAGS_PET, nil, SchoolName(school) or "", school, amount, 0, 0, isCrit)
		elseif MISS_ACTIONS[action] then
			Emit("SWING_MISSED", "", "", FLAGS_UNKNOWN_ENEMY, guid, name, FLAGS_PET, action, false, amount)
		end
		return
	end

	-------------------------------------------------------------- outgoing
	local guid, name, flags, hostile = UnitInfo(unit)
	if call(UnitIsUnit, unit, "player") then return end
	local key = (guid ~= "" and guid) or name
	if key == "" then key = unit end

	if hostile and IsHostileToken(unit) then
		if Seen(key .. action .. tostring(amount)) then return end
		local isDamage = action == "WOUND" and amount and amount > 0
		if not isDamage and not MISS_ACTIONS[action] then return end

		local c = MatchCast("harm", key, name, physical)
		if not c then
			local tapped = call(UnitIsTapDenied, unit)
			if tapped then return end
			if not (Solo() or settings.groupGuess) then return end
		end

		if isDamage then
			if c then
				Emit("SPELL_DAMAGE", playerGUID, playerName, FLAGS_ME, guid, name, flags,
					c.id, c.name, school, amount, -1, school, nil, nil, nil, isCrit, isGlancing, isCrushing, false)
			elseif physical then
				Emit("SWING_DAMAGE", playerGUID, playerName, FLAGS_ME, guid, name, flags,
					amount, -1, school, nil, nil, nil, isCrit, isGlancing, isCrushing, false)
			else
				Emit("SPELL_PERIODIC_DAMAGE", playerGUID, playerName, FLAGS_ME, guid, name, flags,
					nil, SchoolName(school), school, amount, -1, school, nil, nil, nil, isCrit, isGlancing, isCrushing, false)
			end
		else
			if c then
				Emit("SPELL_MISSED", playerGUID, playerName, FLAGS_ME, guid, name, flags,
					c.id, c.name, school, action, false, amount)
			else
				Emit("SWING_MISSED", playerGUID, playerName, FLAGS_ME, guid, name, flags,
					action, false, amount)
			end
		end
		return
	end

	-- your heals on friends: only when they line up with one of your casts
	if not hostile and action == "HEAL" and amount and amount > 0 and friendlyTokens[unit] then
		if Seen(key .. "HEAL" .. tostring(amount)) then return end
		local c = MatchCast("help", key, name)
		if c then
			Emit("SPELL_HEAL", playerGUID, playerName, FLAGS_ME, guid, name, flags,
				c.id, c.name, school, amount, 0, 0, isCrit)
		end
	end
end

-------------------------------------------------------------------------------
-- UNIT_AURA
-------------------------------------------------------------------------------
local auraUnits = { player = true, pet = true, target = true }
local auraCache = { player = {}, pet = {}, target = {} }

local function ReadAura(unit, instanceID)
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID) then return end
	local ok, a = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, instanceID)
	if not ok or type(a) ~= "table" then return end
	local name, id = Plain(a.name), Plain(a.spellId)
	if not name or not id then return end
	local helpful = Plain(a.isHelpful)
	if helpful == nil then
		local harmful = Plain(a.isHarmful)
		if harmful == nil then return end
		helpful = not harmful
	end
	return {
		name = name, id = id, helpful = helpful,
		count = Plain(a.applications) or 0,
		source = Plain(a.sourceUnit),
	}
end

local function Resync(unit)
	local cache = auraCache[unit]
	wipe(cache)
	if not UnitExists(unit) then return end
	if not (C_UnitAuras and C_UnitAuras.GetAuraSlots) then return end
	for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
		local ok, results = pcall(function() return { C_UnitAuras.GetAuraSlots(unit, filter) } end)
		if ok and results then
			for i = 2, #results do
				local okd, a = pcall(C_UnitAuras.GetAuraDataBySlot, unit, results[i])
				if okd and type(a) == "table" then
					local iid = Plain(a.auraInstanceID)
					if iid then
						local info = ReadAura(unit, iid)
						if info then cache[iid] = info end
					end
				end
			end
		end
	end
end

local function EmitAura(eventType, unit, info, amount)
	local dstGUID, dstName, dstFlags = UnitInfo(unit)
	local srcGUID, srcName, srcFlags = "", "", 0
	if info.source then
		srcGUID, srcName, srcFlags = UnitInfo(info.source)
	end
	Emit(eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags,
		info.id, info.name, 1, info.helpful and "BUFF" or "DEBUFF", amount)
end

local function OnUnitAura(unit, updateInfo)
	if not auraUnits[unit] then return end
	if not settings.auras then return end
	if not updateInfo or updateInfo.isFullUpdate then
		Resync(unit)
		return
	end
	local cache = auraCache[unit]
	if updateInfo.addedAuras then
		for _, a in ipairs(updateInfo.addedAuras) do
			local iid = Plain(a.auraInstanceID)
			local info = iid and ReadAura(unit, iid)
			if info then
				cache[iid] = info
				EmitAura("SPELL_AURA_APPLIED", unit, info)
			end
		end
	end
	if updateInfo.updatedAuraInstanceIDs then
		for _, iid in ipairs(updateInfo.updatedAuraInstanceIDs) do
			iid = Plain(iid)
			local info = iid and ReadAura(unit, iid)
			if info then
				local old = cache[iid]
				cache[iid] = info
				if old and info.count > old.count then
					EmitAura("SPELL_AURA_APPLIED_DOSE", unit, info, info.count)
				elseif old then
					EmitAura("SPELL_AURA_REFRESH", unit, info, info.count)
				end
			end
		end
	end
	if updateInfo.removedAuraInstanceIDs then
		for _, iid in ipairs(updateInfo.removedAuraInstanceIDs) do
			iid = Plain(iid)
			local old = iid and cache[iid]
			if old then
				cache[iid] = nil
				EmitAura("SPELL_AURA_REMOVED", unit, old)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
local running = false

-- /gc debug: print what the game actually sends, so problems can be traced
ns.debugFeed = false
local function show(v)
	if v == nil then return "nil" end
	if IsSecret(v) then return "|cffff9900hidden|r" end
	return tostring(v)
end
local function DebugUnitCombat(unit, action, flagText, amount, school)
	if not ns.debugFeed then return end
	print(("|cffff4fa3Gram Combat|r UNIT_COMBAT %s %s %s %s school=%s"):format(
		show(unit), show(action), show(flagText), show(amount), show(school)))
end

Feed:SetScript("OnEvent", function(_, event, ...)
	if event == "UNIT_COMBAT" then
		DebugUnitCombat(...)
		C.SafeCall(OnUnitCombat, ...)
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		C.SafeCall(OnCastSucceeded, ...)
	elseif event == "UNIT_SPELLCAST_SENT" then
		C.SafeCall(OnCastSent, ...)
	elseif event == "UNIT_AURA" then
		C.SafeCall(OnUnitAura, ...)
	elseif event == "PLAYER_TARGET_CHANGED" then
		C.SafeCall(Resync, "target")
	elseif event == "UNIT_PET" then
		if ... == "player" then C.SafeCall(Resync, "pet") end
	elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
		-- quietly catch up on anything that was hidden during combat
		playerGUID = UnitGUID("player")
		playerName = UnitName("player")
		for u in next, auraUnits do C.SafeCall(Resync, u) end
	end
end)

local function TryRegister(event, ...)
	pcall(Feed.RegisterEvent, Feed, event, ...)
end

function ns.StartFeed()
	if running then return end
	running = true
	playerGUID = UnitGUID("player")
	playerName = UnitName("player")
	TryRegister("UNIT_COMBAT")
	TryRegister("UNIT_AURA")
	if Feed.RegisterUnitEvent then
		pcall(Feed.RegisterUnitEvent, Feed, "UNIT_SPELLCAST_SUCCEEDED", "player")
		pcall(Feed.RegisterUnitEvent, Feed, "UNIT_SPELLCAST_SENT", "player")
	else
		TryRegister("UNIT_SPELLCAST_SUCCEEDED")
		TryRegister("UNIT_SPELLCAST_SENT")
	end
	TryRegister("PLAYER_TARGET_CHANGED")
	TryRegister("UNIT_PET")
	TryRegister("PLAYER_ENTERING_WORLD")
	TryRegister("PLAYER_REGEN_ENABLED")
	for u in next, auraUnits do C.SafeCall(Resync, u) end
end

-- /gc test: push a few fake hits through the whole display
function ns.TestFeed()
	local me, myName = UnitGUID("player"), UnitName("player")
	Emit("SWING_DAMAGE", "", "", FLAGS_UNKNOWN_ENEMY, me, myName, FLAGS_ME, 142, -1, 1, nil, nil, nil, false, false, false, false)
	Emit("SPELL_DAMAGE", "", "", FLAGS_UNKNOWN_ENEMY, me, myName, FLAGS_ME, nil, STRING_SCHOOL_FIRE, 4, 388, -1, 4, nil, nil, nil, true, false, false, false)
	Emit("SPELL_HEAL", "", "", 0, me, myName, FLAGS_ME, nil, STRING_SCHOOL_HOLY, 2, 260, 0, 0, false)
	Emit("SWING_DAMAGE", me, myName, FLAGS_ME, "Creature-0-0-0-0-0-0", "Test Dummy", FLAGS_UNKNOWN_ENEMY, 97, -1, 1, nil, nil, nil, false, false, false, false)
	Emit("SPELL_DAMAGE", me, myName, FLAGS_ME, "Creature-0-0-0-0-0-0", "Test Dummy", FLAGS_UNKNOWN_ENEMY, 133, (C.GetSpellInfo(133)) or "Fireball", 4, 512, -1, 4, nil, nil, nil, true, false, false, false)
	Emit("SWING_MISSED", me, myName, FLAGS_ME, "Creature-0-0-0-0-0-0", "Test Dummy", FLAGS_UNKNOWN_ENEMY, "PARRY", false, 0)
	-- the same display Forever's hidden numbers use
	if ns.Secret then
		ns.Secret:Show("Incoming", "-%s", 1893, { color = "ff4d4d" })
		ns.Secret:Show("Incoming", "+%s", 733, { color = "4dff4d", icon = C.GetSpellTexture(2050) })
		ns.Secret:Show("Outgoing", "%s!", 5546, { color = "ffe680", crit = true, icon = C.GetSpellTexture(20473) or C.GetSpellTexture(133) })
		ns.Secret:Show("Outgoing", "%s", 30, { color = "ffffff", icon = C.GetSpellTexture(6603) })
	end
end

function ns.FeedStatus()
	local regs = {}
	for _, e in ipairs({ "UNIT_COMBAT", "UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED" }) do
		regs[#regs + 1] = e .. "=" .. tostring(Feed:IsEventRegistered(e) and "on" or "OFF")
	end
	local n = 0
	for _ in next, handlers do n = n + 1 end
	return ("feed %s, listeners %d, %s"):format(running and "running" or "STOPPED", n, table.concat(regs, " "))
end

function ns.StopFeed()
	if not running then return end
	running = false
	Feed:UnregisterAllEvents()
end
