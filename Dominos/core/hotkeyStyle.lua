-- Dominos hotkey style: changes font / size / colour of the hotkey text on action buttons.
-- Part of this Dominos fork (Dominos reuses the Blizzard buttons).
-- Commands: /hks  (see /hks help)

local FONTS = {
	frizqt = "Fonts\\FRIZQT__.TTF",
	arialn = "Fonts\\ARIALN.TTF",
	skurri = "Fonts\\skurri.ttf",
	morpheus = "Fonts\\MORPHEUS.ttf",
}
local DEFAULTS = { font = FONTS.frizqt, size = 14, outline = "OUTLINE", r = 1, g = 1, b = 0 }
local db = DEFAULTS
local cache = {}   -- button -> hotkey fontstring (or false)

local PREFIXES = {
	{ "ActionButton", 12 }, { "BonusActionButton", 12 },
	{ "MultiBarBottomLeftButton", 12 }, { "MultiBarBottomRightButton", 12 },
	{ "MultiBarRightButton", 12 }, { "MultiBarLeftButton", 12 },
	{ "DominosActionButton", 48 },
}

local function HotKeyOf(btn)
	local hk = cache[btn]
	if hk == nil then
		local name = btn and btn.GetName and btn:GetName()
		hk = name and _G[name .. "HotKey"] or false
		cache[btn] = hk
	end
	return hk
end

local function Style(hk)
	if not pcall(hk.SetFont, hk, db.font, db.size, db.outline) then
		hk:SetFont(DEFAULTS.font, db.size, db.outline)
	end
end

-- cheap re-apply of the colour (the game resets it on every range / usable update)
local function Recolor(btn)
	local hk = HotKeyOf(btn)
	if hk then
		hk:SetTextColor(db.r, db.g, db.b)
		hk:SetVertexColor(1, 1, 1)
	end
end

local function ApplyAll()
	for _, p in ipairs(PREFIXES) do
		for i = 1, p[2] do
			local btn = _G[p[1] .. i]
			if btn then
				local hk = HotKeyOf(btn)
				if hk then Style(hk); Recolor(btn) end
			end
		end
	end
end

local function Hooked(btn) Recolor(btn) end
local function HookedFull(btn)
	local hk = HotKeyOf(btn)
	if hk then Style(hk); Recolor(btn) end
end

local function Hook(name, fn)
	if _G[name] then hooksecurefunc(name, fn) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	DominosHotkeyStyleDB = DominosHotkeyStyleDB or {}
	for k, v in pairs(DEFAULTS) do
		if DominosHotkeyStyleDB[k] == nil then DominosHotkeyStyleDB[k] = v end
	end
	db = DominosHotkeyStyleDB
	Hook("ActionButton_OnUpdate", Hooked)
	Hook("ActionButton_UpdateUsable", Hooked)
	Hook("ActionButton_UpdateHotkeys", HookedFull)
	Hook("ActionButton_Update", HookedFull)
	ApplyAll()
end)

local function Say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99HotkeyStyle:|r " .. msg) end

SLASH_HOTKEYSTYLE1 = "/hks"
SlashCmdList["HOTKEYSTYLE"] = function(msg)
	local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
	cmd = cmd:lower()
	if cmd == "size" then
		local n = tonumber(rest)
		if not n or n < 4 or n > 40 then return Say("usage: /hks size 14   (4-40)") end
		db.size = n
	elseif cmd == "color" or cmd == "colour" then
		local r, g, b = rest:match("^([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)$")
		r, g, b = tonumber(r), tonumber(g), tonumber(b)
		if not r then return Say("usage: /hks color 1 1 0   (red green blue, 0-1)") end
		db.r, db.g, db.b = r, g, b
	elseif cmd == "font" then
		local path = FONTS[rest:lower()] or (rest ~= "" and rest)
		if not path then return Say("usage: /hks font frizqt|arialn|skurri|morpheus  or a path") end
		db.font = path
	elseif cmd == "outline" then
		local v = rest:lower()
		db.outline = (v == "off" and "") or (v == "thick" and "THICKOUTLINE") or "OUTLINE"
	elseif cmd == "reset" then
		for k, v in pairs(DEFAULTS) do db[k] = v end
	else
		Say("/hks size <n> | color <r> <g> <b> | font <name|path> | outline on|off|thick | reset")
		return
	end
	ApplyAll()
end
