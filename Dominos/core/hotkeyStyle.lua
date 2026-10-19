--[[
	hotkeyStyle.lua
	Font, size, colour, outline and x/y offset of the keybinding text on action buttons.
	Settings are stored per profile in Dominos.db.profile.hotkeyStyle and are edited in
	Interface Options > Dominos > Hotkey Text. Dominos reuses the Blizzard buttons, so the
	text is restyled by hooking the Blizzard button update functions (the game resets
	colour / font on its own updates, so a one-time SetFont would not stick).
--]]
local Dominos = Dominos
local LSM = LibStub("LibSharedMedia-3.0", true)

local HS = {}
Dominos.HotkeyStyle = HS

local DEFAULT_FONT = "Friz Quadrata TT"
local FALLBACK_FONTS = {
	["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
	["Arial Narrow"] = "Fonts\\ARIALN.TTF",
	["Skurri"] = "Fonts\\skurri.ttf",
	["Morpheus"] = "Fonts\\MORPHEUS.ttf",
}

HS.DEFAULTS = {
	enabled = false,
	font = DEFAULT_FONT,
	size = 12,
	outline = "OUTLINE", -- "", "OUTLINE" or "THICKOUTLINE"
	r = 1, g = 1, b = 0,
	x = 0, y = 0,
}

local PREFIXES = {
	{ "ActionButton", 12 }, { "BonusActionButton", 12 },
	{ "MultiBarBottomLeftButton", 12 }, { "MultiBarBottomRightButton", 12 },
	{ "MultiBarRightButton", 12 }, { "MultiBarLeftButton", 12 },
	{ "DominosActionButton", 48 },
}

local cfg            -- active settings table (nil until the database exists)
local cache = {}     -- button -> hotkey fontstring (or false)
local orig = {}      -- hotkey fontstring -> original look

------------------------------------------------------------------
-- Settings
------------------------------------------------------------------
local function LoadConfig()
	local db = Dominos.db
	if not (db and db.profile) then cfg = nil return end
	local t = db.profile.hotkeyStyle
	if type(t) ~= "table" then
		t = {}
		db.profile.hotkeyStyle = t
	end
	for k, v in pairs(HS.DEFAULTS) do
		if t[k] == nil then t[k] = v end
	end
	cfg = t
end

function HS:Get(key)
	if not cfg then LoadConfig() end
	return cfg and cfg[key]
end

function HS:GetFontPath(name)
	name = name or (cfg and cfg.font) or DEFAULT_FONT
	local path = LSM and LSM:Fetch("font", name, true)
	return path or FALLBACK_FONTS[name] or FALLBACK_FONTS[DEFAULT_FONT]
end

function HS:GetFontList()
	if LSM then return LSM:List("font") end
	local list = {}
	for name in pairs(FALLBACK_FONTS) do list[#list + 1] = name end
	table.sort(list)
	return list
end

------------------------------------------------------------------
-- Applying
------------------------------------------------------------------
local function HotKeyOf(btn)
	local hk = cache[btn]
	if hk == nil then
		local name = btn and btn.GetName and btn:GetName()
		hk = name and _G[name .. "HotKey"] or false
		cache[btn] = hk
	end
	return hk
end

local function Remember(hk)
	if orig[hk] then return orig[hk] end
	local font, size, flags = hk:GetFont()
	local r, g, b = hk:GetTextColor()
	local o = { font = font, size = size, flags = flags, r = r, g = g, b = b }
	if hk:GetNumPoints() > 0 then
		o.point, o.rel, o.relPoint, o.x, o.y = hk:GetPoint(1)
	end
	orig[hk] = o
	return o
end

local function Position(hk, o)
	if o.point then
		hk:ClearAllPoints()
		hk:SetPoint(o.point, o.rel, o.relPoint, (o.x or 0) + cfg.x, (o.y or 0) + cfg.y)
	end
end

local function Style(hk)
	local o = Remember(hk)
	if not pcall(hk.SetFont, hk, HS:GetFontPath(), cfg.size, cfg.outline) then
		hk:SetFont(HS:GetFontPath(DEFAULT_FONT), cfg.size, cfg.outline)
	end
	hk:SetTextColor(cfg.r, cfg.g, cfg.b)
	hk:SetVertexColor(1, 1, 1)
	Position(hk, o)
end

local function Restore(hk)
	local o = orig[hk]
	if not o then return end
	if o.font then hk:SetFont(o.font, o.size, o.flags) end
	hk:SetTextColor(o.r, o.g, o.b)
	if o.point then
		hk:ClearAllPoints()
		hk:SetPoint(o.point, o.rel, o.relPoint, o.x, o.y)
	end
end

function HS:Apply()
	if not cfg then LoadConfig() end
	if not cfg then return end
	for _, p in ipairs(PREFIXES) do
		for i = 1, p[2] do
			local btn = _G[p[1] .. i]
			local hk = btn and HotKeyOf(btn)
			if hk then
				if cfg.enabled then Style(hk) else Restore(hk) end
			end
		end
	end
end

function HS:Set(key, value)
	if not cfg then LoadConfig() end
	if not cfg then return end
	cfg[key] = value
	self:Apply()
end

function HS:SetColor(r, g, b)
	if not cfg then LoadConfig() end
	if not cfg then return end
	cfg.r, cfg.g, cfg.b = r, g, b
	self:Apply()
end

function HS:Reset()
	if not cfg then LoadConfig() end
	if not cfg then return end
	for k, v in pairs(self.DEFAULTS) do cfg[k] = v end
	self:Apply()
end

function HS:Refresh()
	LoadConfig()
	self:Apply()
end

------------------------------------------------------------------
-- Hooks (the game resets colour / font on its own updates)
------------------------------------------------------------------
local function OnColorUpdate(btn)
	if not (cfg and cfg.enabled) then return end
	local hk = HotKeyOf(btn)
	if hk then
		hk:SetTextColor(cfg.r, cfg.g, cfg.b)
		hk:SetVertexColor(1, 1, 1)
	end
end

local function OnFullUpdate(btn)
	if not (cfg and cfg.enabled) then return end
	local hk = HotKeyOf(btn)
	if hk then Style(hk) end
end

local function Hook(name, fn)
	if _G[name] then hooksecurefunc(name, fn) end
end

Hook("ActionButton_OnUpdate", OnColorUpdate)
Hook("ActionButton_UpdateUsable", OnColorUpdate)
Hook("ActionButton_UpdateHotkeys", OnFullUpdate)
Hook("ActionButton_Update", OnFullUpdate)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	if Dominos.db then
		for _, ev in ipairs({ "OnProfileChanged", "OnProfileCopied", "OnProfileReset" }) do
			Dominos.db.RegisterCallback(HS, ev, "Refresh")
		end
	end
	HS:Refresh()
end)

------------------------------------------------------------------
-- /hks opens the options page
------------------------------------------------------------------
SLASH_DOMINOSHOTKEYSTYLE1 = "/hks"
SlashCmdList["DOMINOSHOTKEYSTYLE"] = function()
	if Dominos:ShowOptions() and HS.panel then
		InterfaceOptionsFrame_OpenToCategory(HS.panel)
		InterfaceOptionsFrame_OpenToCategory(HS.panel)
	end
end
