--[[
hotkeyStyle.lua
Options page for the keybinding text style (font, size, colour, outline, x/y offset).
The logic lives in Dominos/core/hotkeyStyle.lua (Dominos.HotkeyStyle).
--]]
local Dominos = Dominos
local HS = Dominos.HotkeyStyle
local L = LibStub("AceLocale-3.0"):GetLocale("Dominos-Config")
local _G = _G

local panel = Dominos.Options:New("DominosHotkeyStyle", L.HotkeyStyle, L.HotkeyStyleDesc, nil, GetAddOnMetadata("Dominos", "title"))
HS.panel = panel

local refreshing = false
local controls = {}

local function SetDDWidth(dd, w)
	if not pcall(UIDropDownMenu_SetWidth, dd, w) then
		pcall(UIDropDownMenu_SetWidth, w, dd)
	end
end

local function SetDDText(dd, text)
	_G[dd:GetName() .. "Text"]:SetText(text)
end

--[[ Enable ]]--
local enable = panel:NewCheckButton(L.HotkeyStyleEnable)
enable:SetPoint("TOPLEFT", 16, -64)
enable:SetScript("OnClick", function(self) HS:Set("enabled", self:GetChecked() and true or false) end)
controls.enable = enable

--[[ Font dropdown (grouped in sub menus when the list is long) ]]--
local CHUNK = 20
local fontDD = panel:NewDropdown(L.HotkeyFont)
fontDD:SetPoint("TOPLEFT", 0, -112)

local function Font_OnClick(self)
	HS:Set("font", self.value)
	SetDDText(fontDD, self.value)
	CloseDropDownMenus()
end

local function AddFont(name, level)
	local info = {}
	info.text = name
	info.value = name
	info.func = Font_OnClick
	info.checked = (HS:Get("font") == name)
	UIDropDownMenu_AddButton(info, level)
end

function fontDD:Initialize(level)
	level = level or 1
	local fonts = HS:GetFontList()
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
controls.font = fontDD

--[[ Outline dropdown ]]--
local outlineDD = panel:NewDropdown(L.HotkeyOutline)
outlineDD:SetPoint("LEFT", fontDD, "RIGHT", -6, 0)

local OUTLINES = {
	{ "", L.HotkeyOutlineNone },
	{ "OUTLINE", L.HotkeyOutlineThin },
	{ "THICKOUTLINE", L.HotkeyOutlineThick },
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
		info.checked = (HS:Get("outline") == o[1])
		info.func = function(self)
			HS:Set("outline", self.value)
			SetDDText(outlineDD, OutlineText(self.value))
		end
		UIDropDownMenu_AddButton(info)
	end
end
UIDropDownMenu_Initialize(outlineDD, outlineDD.Initialize)
SetDDWidth(outlineDD, 120)
controls.outline = outlineDD

--[[ Sliders ]]--
local function NewValueSlider(text, low, high, key, anchorTo, offsetY)
	local s = panel:NewSlider(text, low, high, 1, true)
	s:SetWidth(220)
	s:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, offsetY)
	s:SetScript("OnValueChanged", function(self, value)
		value = floor(value + 0.5)
		self.valText:SetText(value)
		if not refreshing and HS:Get(key) ~= value then HS:Set(key, value) end
	end)
	controls[key] = s
	return s
end

local sizeSlider = NewValueSlider(L.HotkeySize, 6, 32, "size", fontDD, -34)
local xSlider = NewValueSlider(L.HotkeyOffsetX, -30, 30, "x", sizeSlider, -34)
local ySlider = NewValueSlider(L.HotkeyOffsetY, -30, 30, "y", xSlider, -34)

--[[ Colour ]]--
local colorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
colorLabel:SetPoint("TOPLEFT", sizeSlider, "TOPRIGHT", 50, 4)
colorLabel:SetText(L.HotkeyColor)

local swatch = CreateFrame("Button", "DominosHotkeyStyleColor", panel)
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
	fill:SetVertexColor(HS:Get("r"), HS:Get("g"), HS:Get("b"))
end

swatch:SetScript("OnClick", function()
	local r, g, b = HS:Get("r"), HS:Get("g"), HS:Get("b")
	ColorPickerFrame.hasOpacity = false
	ColorPickerFrame.opacity = nil
	ColorPickerFrame.previousValues = { r, g, b }
	ColorPickerFrame.func = function()
		HS:SetColor(ColorPickerFrame:GetColorRGB())
		UpdateSwatch()
	end
	ColorPickerFrame.opacityFunc = nil
	ColorPickerFrame.cancelFunc = function(prev)
		HS:SetColor(prev[1], prev[2], prev[3])
		UpdateSwatch()
	end
	ColorPickerFrame:SetColorRGB(r, g, b)
	ColorPickerFrame:Hide()
	ColorPickerFrame:Show()
end)

--[[ Reset ]]--
local reset = panel:NewButton(L.HotkeyReset, 140, 22)
reset:SetPoint("TOPLEFT", ySlider, "BOTTOMLEFT", 0, -28)
reset:SetScript("OnClick", function()
	HS:Reset()
	panel:GetScript("OnShow")(panel)
end)

--[[ Refresh controls from the active profile ]]--
panel:SetScript("OnShow", function()
	refreshing = true
	enable:SetChecked(HS:Get("enabled"))
	SetDDText(fontDD, HS:Get("font"))
	SetDDText(outlineDD, OutlineText(HS:Get("outline")))
	sizeSlider:SetValue(HS:Get("size"))
	xSlider:SetValue(HS:Get("x"))
	ySlider:SetValue(HS:Get("y"))
	UpdateSwatch()
	refreshing = false
end)
