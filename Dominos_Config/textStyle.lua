--[[
textStyle.lua
Options page for the texts on the action buttons (keybinding text, macro name, count):
font, size, colour, outline and x/y offset, separately for each text.
The logic lives in Dominos/core/textStyle.lua (Dominos.TextStyle).
--]]
local Dominos = Dominos
local TS = Dominos.TextStyle
local L = LibStub("AceLocale-3.0"):GetLocale("Dominos-Config")
local _G = _G

local panel = Dominos.Options:New("DominosTextStyle", L.TextStyle, L.TextStyleDesc, nil, GetAddOnMetadata("Dominos", "title"))
TS.panel = panel

local current = "hotkey"   -- element being edited
local refreshing = false

local ELEMENT_NAMES = { hotkey = L.TextHotkey, macro = L.TextMacro, count = L.TextCount }

local function SetDDWidth(dd, w)
	if not pcall(UIDropDownMenu_SetWidth, dd, w) then
		pcall(UIDropDownMenu_SetWidth, w, dd)
	end
end

local function SetDDText(dd, text)
	_G[dd:GetName() .. "Text"]:SetText(text)
end

local function Get(key) return TS:Get(current, key) end
local function Set(key, value) TS:Set(current, key, value) end

local Refresh   -- defined below

--[[ Element selector ]]--
local elementDD = panel:NewDropdown(L.TextElement)
elementDD:SetPoint("TOPLEFT", 0, -78)

function elementDD:Initialize()
	for _, el in ipairs(TS.ELEMENTS) do
		local info = {}
		info.text = ELEMENT_NAMES[el]
		info.value = el
		info.checked = (current == el)
		info.func = function(self)
			current = self.value
			Refresh()
		end
		UIDropDownMenu_AddButton(info)
	end
end
UIDropDownMenu_Initialize(elementDD, elementDD.Initialize)
SetDDWidth(elementDD, 200)

--[[ Enable ]]--
local enable = panel:NewCheckButton(L.TextStyleEnable)
enable:SetPoint("TOPLEFT", 16, -112)
enable:SetScript("OnClick", function(self) Set("enabled", self:GetChecked() and true or false) end)

--[[ Font dropdown (grouped in sub menus when the list is long) ]]--
local CHUNK = 20
local fontDD = panel:NewDropdown(L.TextFont)
fontDD:SetPoint("TOPLEFT", 0, -170)

local function Font_OnClick(self)
	Set("font", self.value)
	SetDDText(fontDD, self.value)
	CloseDropDownMenus()
end

local function AddFont(name, level)
	local info = {}
	info.text = name
	info.value = name
	info.func = Font_OnClick
	info.checked = (Get("font") == name)
	UIDropDownMenu_AddButton(info, level)
end

function fontDD:Initialize(level)
	level = level or 1
	local fonts = TS:GetFontList()
	if #fonts <= CHUNK then
		for _, name in ipairs(fonts) do AddFont(name, level) end
	elseif level == 1 then
		for i = 1, #fonts, CHUNK do
			local info = {}
			info.text = fonts[i]:sub(1, 1) .. "…  " .. fonts[min(i + CHUNK - 1, #fonts)]:sub(1, 1)
			info.value = i
			info.hasArrow = true
			info.notCheckable = true
			UIDropDownMenu_AddButton(info, 1)
		end
	else
		local start = UIDROPDOWNMENU_MENU_VALUE
		for i = start, min(start + CHUNK - 1, #fonts) do AddFont(fonts[i], 2) end
	end
end
UIDropDownMenu_Initialize(fontDD, fontDD.Initialize)
SetDDWidth(fontDD, 160)

--[[ Outline dropdown ]]--
local outlineDD = panel:NewDropdown(L.TextOutline)
outlineDD:SetPoint("LEFT", fontDD, "RIGHT", -6, 0)

local OUTLINES = {
	{ "", L.TextOutlineNone },
	{ "OUTLINE", L.TextOutlineThin },
	{ "THICKOUTLINE", L.TextOutlineThick },
}
local function OutlineText(value)
	for _, o in ipairs(OUTLINES) do
		if o[1] == value then return o[2] end
	end
	return OUTLINES[2][2]
end

function outlineDD:Initialize()
	for _, o in ipairs(OUTLINES) do
		local info = {}
		info.text = o[2]
		info.value = o[1]
		info.checked = (Get("outline") == o[1])
		info.func = function(self)
			Set("outline", self.value)
			SetDDText(outlineDD, OutlineText(self.value))
		end
		UIDropDownMenu_AddButton(info)
	end
end
UIDropDownMenu_Initialize(outlineDD, outlineDD.Initialize)
SetDDWidth(outlineDD, 120)

--[[ Sliders ]]--
local sliders = {}
local function NewValueSlider(text, low, high, key, anchorTo, offsetY)
	local s = panel:NewSlider(text, low, high, 1, true)
	s:SetWidth(220)
	s:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, offsetY)
	s:SetScript("OnValueChanged", function(self, value)
		value = floor(value + 0.5)
		self.valText:SetText(value)
		if not refreshing and Get(key) ~= value then Set(key, value) end
	end)
	sliders[key] = s
	return s
end

local sizeSlider = NewValueSlider(L.TextSize, 6, 32, "size", fontDD, -34)
local xSlider = NewValueSlider(L.TextOffsetX, -30, 30, "x", sizeSlider, -34)
local ySlider = NewValueSlider(L.TextOffsetY, -30, 30, "y", xSlider, -34)

--[[ Colour ]]--
local colorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
colorLabel:SetPoint("TOPLEFT", sizeSlider, "TOPRIGHT", 50, 4)
colorLabel:SetText(L.TextColor)

local swatch = CreateFrame("Button", "DominosTextStyleColor", panel)
swatch:SetWidth(28)
swatch:SetHeight(28)
swatch:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -4)

local border = swatch:CreateTexture(nil, "BACKGROUND")
border:SetAllPoints()
border:SetTexture(1, 1, 1)
local fill = swatch:CreateTexture(nil, "ARTWORK")
fill:SetPoint("TOPLEFT", 2, -2)
fill:SetPoint("BOTTOMRIGHT", -2, 2)
fill:SetTexture(1, 1, 1)
swatch:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

local function UpdateSwatch()
	fill:SetVertexColor(Get("r"), Get("g"), Get("b"))
end

swatch:SetScript("OnClick", function()
	local el = current
	local r, g, b = Get("r"), Get("g"), Get("b")
	ColorPickerFrame.hasOpacity = false
	ColorPickerFrame.opacity = nil
	ColorPickerFrame.previousValues = { r, g, b }
	ColorPickerFrame.func = function()
		TS:SetColor(el, ColorPickerFrame:GetColorRGB())
		if el == current then UpdateSwatch() end
	end
	ColorPickerFrame.opacityFunc = nil
	ColorPickerFrame.cancelFunc = function(prev)
		TS:SetColor(el, prev[1], prev[2], prev[3])
		if el == current then UpdateSwatch() end
	end
	ColorPickerFrame:SetColorRGB(r, g, b)
	ColorPickerFrame:Hide()
	ColorPickerFrame:Show()
end)

--[[ Reset (current text only) ]]--
local reset = panel:NewButton(L.TextReset, 170, 22)
reset:SetPoint("TOPLEFT", ySlider, "BOTTOMLEFT", 0, -28)
reset:SetScript("OnClick", function()
	TS:Reset(current)
	Refresh()
end)

--[[ Refresh controls from the active profile ]]--
function Refresh()
	refreshing = true
	SetDDText(elementDD, ELEMENT_NAMES[current])
	enable:SetChecked(Get("enabled"))
	SetDDText(fontDD, Get("font"))
	SetDDText(outlineDD, OutlineText(Get("outline")))
	sizeSlider:SetValue(Get("size"))
	xSlider:SetValue(Get("x"))
	ySlider:SetValue(Get("y"))
	UpdateSwatch()
	refreshing = false
end
panel:SetScript("OnShow", Refresh)
