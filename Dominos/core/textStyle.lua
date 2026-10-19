--[[
	textStyle.lua
	Font, size, colour, outline and x/y offset of the texts on action buttons:
	the keybinding text, the macro name and the count (stacks / charges).
	Each of them has its own settings, stored per profile in Dominos.db.profile.textStyle
	and edited in Interface Options > Dominos > Text. Dominos reuses the Blizzard buttons,
	so the texts are restyled by hooking the Blizzard button update functions (the game
	resets colour / font on its own updates, so a one-time SetFont would not stick).
--]]
local Dominos = Dominos
local LSM = LibStub("LibSharedMedia-3.0", true)

local TS = {}
Dominos.TextStyle = TS

local DEFAULT_FONT = "Friz Quadrata TT"
local FALLBACK_FONTS = {
	["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
	["Arial Narrow"] = "Fonts\\ARIALN.TTF",
	["Skurri"] = "Fonts\\skurri.ttf",
	["Morpheus"] = "Fonts\\MORPHEUS.ttf",
}

-- element -> suffix of the fontstring name on the button
TS.ELEMENTS = { "hotkey", "macro", "count" }
local SUFFIX = { hotkey = "HotKey", macro = "Name", count = "Count" }

local function Defaults(size, r, g, b)
	return {
		enabled = false, font = DEFAULT_FONT, size = size, outline = "OUTLINE",
		r = r, g = g, b = b, x = 0, y = 0,
	}
end
TS.DEFAULTS = {
	hotkey = Defaults(12, 1, 1, 0),
	macro = Defaults(10, 1, 1, 1),
	count = Defaults(14, 1, 1, 1),
}

local PREFIXES = {
	{ "ActionButton", 12 }, { "BonusActionButton", 12 },
	{ "MultiBarBottomLeftButton", 12 }, { "MultiBarBottomRightButton", 12 },
	{ "MultiBarRightButton", 12 }, { "MultiBarLeftButton", 12 },
	{ "DominosActionButton", 48 },
}

local cfg            -- cfg[element] = settings table (nil until the database exists)
local cache = {}     -- button -> { hotkey = fs, macro = fs, count = fs }
local orig = {}      -- fontstring -> original look

------------------------------------------------------------------
-- Settings
------------------------------------------------------------------
local function LoadConfig()
	local db = Dominos.db
	if not (db and db.profile) then cfg = nil return end
	local p = db.profile
	if type(p.textStyle) ~= "table" then
		p.textStyle = {}
		-- settings of the first version (keybinding text only)
		if type(p.hotkeyStyle) == "table" then
			p.textStyle.hotkey = p.hotkeyStyle
		end
	end
	for _, el in ipairs(TS.ELEMENTS) do
		local t = p.textStyle[el]
		if type(t) ~= "table" then
			t = {}
			p.textStyle[el] = t
		end
		for k, v in pairs(TS.DEFAULTS[el]) do
			if t[k] == nil then t[k] = v end
		end
	end
	cfg = p.textStyle
end

function TS:Get(el, key)
	if not cfg then LoadConfig() end
	return cfg and cfg[el] and cfg[el][key]
end

function TS:GetFontPath(name)
	name = name or DEFAULT_FONT
	local path = LSM and LSM:Fetch("font", name, true)
	return path or FALLBACK_FONTS[name] or FALLBACK_FONTS[DEFAULT_FONT]
end

function TS:GetFontList()
	if LSM then return LSM:List("font") end
	local list = {}
	for name in pairs(FALLBACK_FONTS) do list[#list + 1] = name end
	table.sort(list)
	return list
end

------------------------------------------------------------------
-- Applying
------------------------------------------------------------------
local function TextOf(btn, el)
	local c = cache[btn]
	if not c then
		c = {}
		cache[btn] = c
	end
	local fs = c[el]
	if fs == nil then
		local name = btn and btn.GetName and btn:GetName()
		fs = name and _G[name .. SUFFIX[el]] or false
		c[el] = fs
	end
	return fs
end

local function Remember(fs)
	if orig[fs] then return orig[fs] end
	local font, size, flags = fs:GetFont()
	local r, g, b = fs:GetTextColor()
	local o = { font = font, size = size, flags = flags, r = r, g = g, b = b }
	if fs:GetNumPoints() > 0 then
		o.point, o.rel, o.relPoint, o.x, o.y = fs:GetPoint(1)
	end
	orig[fs] = o
	return o
end

local function Style(fs, el)
	local c = cfg[el]
	local o = Remember(fs)
	if not pcall(fs.SetFont, fs, TS:GetFontPath(c.font), c.size, c.outline) then
		fs:SetFont(TS:GetFontPath(DEFAULT_FONT), c.size, c.outline)
	end
	fs:SetTextColor(c.r, c.g, c.b)
	if el == "hotkey" then fs:SetVertexColor(1, 1, 1) end
	if o.point then
		fs:ClearAllPoints()
		fs:SetPoint(o.point, o.rel, o.relPoint, (o.x or 0) + c.x, (o.y or 0) + c.y)
	end
end

local function Restore(fs)
	local o = orig[fs]
	if not o then return end
	if o.font then fs:SetFont(o.font, o.size, o.flags) end
	fs:SetTextColor(o.r, o.g, o.b)
	if o.point then
		fs:ClearAllPoints()
		fs:SetPoint(o.point, o.rel, o.relPoint, o.x, o.y)
	end
end

local function ApplyButton(btn, only)
	for _, el in ipairs(TS.ELEMENTS) do
		if not only or only == el then
			local fs = TextOf(btn, el)
			if fs then
				if cfg[el].enabled then Style(fs, el) else Restore(fs) end
			end
		end
	end
end

function TS:Apply(only)
	if not cfg then LoadConfig() end
	if not cfg then return end
	for _, p in ipairs(PREFIXES) do
		for i = 1, p[2] do
			local btn = _G[p[1] .. i]
			if btn then ApplyButton(btn, only) end
		end
	end
end

local function Ready()
	if not cfg then LoadConfig() end
	return cfg
end

function TS:Set(el, key, value)
	if not Ready() then return end
	cfg[el][key] = value
	self:Apply(el)
end

function TS:SetColor(el, r, g, b)
	if not Ready() then return end
	local c = cfg[el]
	c.r, c.g, c.b = r, g, b
	self:Apply(el)
end

function TS:Reset(el)
	if not Ready() then return end
	for k, v in pairs(self.DEFAULTS[el]) do cfg[el][k] = v end
	self:Apply(el)
end

function TS:Refresh()
	LoadConfig()
	self:Apply()
end

------------------------------------------------------------------
-- Hooks (the game resets colour / font on its own updates)
------------------------------------------------------------------
-- cheap: runs every frame for the range check, only fixes the hotkey colour
local function OnColorUpdate(btn)
	local c = cfg and cfg.hotkey
	if not (c and c.enabled) then return end
	local fs = TextOf(btn, "hotkey")
	if fs then
		fs:SetTextColor(c.r, c.g, c.b)
		fs:SetVertexColor(1, 1, 1)
	end
end

local function OnFullUpdate(btn)
	if not cfg then return end
	ApplyButton(btn)
end

local function Hook(name, fn)
	if _G[name] then hooksecurefunc(name, fn) end
end

Hook("ActionButton_OnUpdate", OnColorUpdate)
Hook("ActionButton_UpdateUsable", OnColorUpdate)
Hook("ActionButton_UpdateHotkeys", OnFullUpdate)
Hook("ActionButton_UpdateCount", OnFullUpdate)
Hook("ActionButton_Update", OnFullUpdate)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	if Dominos.db then
		for _, ev in ipairs({ "OnProfileChanged", "OnProfileCopied", "OnProfileReset" }) do
			Dominos.db.RegisterCallback(TS, ev, "Refresh")
		end
	end
	TS:Refresh()
end)

------------------------------------------------------------------
-- /hks and /dtext open the options page
------------------------------------------------------------------
SLASH_DOMINOSTEXTSTYLE1 = "/hks"
SLASH_DOMINOSTEXTSTYLE2 = "/dtext"
SlashCmdList["DOMINOSTEXTSTYLE"] = function()
	if Dominos:ShowOptions() and TS.panel then
		InterfaceOptionsFrame_OpenToCategory(TS.panel)
		InterfaceOptionsFrame_OpenToCategory(TS.panel)
	end
end
