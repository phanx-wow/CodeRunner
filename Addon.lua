--[[--------------------------------------------------------------------
	Code Runner
	Edit and run Lua code in-game.
	Inspired by Tekkub's addon tekPad.
	Copyright (c) 2014-2016 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/CodeRunner
----------------------------------------------------------------------]]

local FONT_SIZE = 18
local FONT_R, FONT_G, FONT_B = 0.95, 0.85, 0.65

------------------------------------------------------------------------

local ADDON = ...
local db, SELECTION, GetFontFile
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local SCROLL_FRAME_HEIGHT, LINE_HEIGHT, offset, maxOffset = 332, 12, 0, 0

local L = {
	BINDING_HEADER =  GetAddOnMetadata(ADDON, "Title") or ADDON,
	BINDING_NAME_TOGGLE = "Toggle CodeRunner",
	RUN = "Go!",
	SAVE = "Save",
	REVERT = "Revert",
	REVERT_TOOLTIP = "Go back to the previously saved version of the code. Your code is saved automatically when you close the window or reload the UI.",
	RELOAD = "Reload UI",
}
if GetLocale() == "deDE" then
	L.BINDING_NAME_TOGGLE = "CodeRunner an/aus"
	L.RUN = "Los!"
	L.SAVE = "Speichern"
	L.REVERT = "Zurück"
	L.REVERT_TOOLTIP = "Auf die zuletzt gespeicherte Version des Codes zurückkehren. Der Code wird beim Schließen des Fensters oder Neuladen der UI automatisch gespeichert."
	L.RELOAD = "UI neuladen"
elseif GetLocale():match("es") then
	L.BINDING_NAME_TOGGLE = "Mostrar/ocultar CodeRunner"
	L.RUN = "Vamos!"
	L.SAVE = "Guardar"
	L.REVERT =  "Volver"
	L.REVERT_TOOLTIP = "Volver a la última versión guardada del codigo. El codigo se guarda automáticamente al cerrar la ventana o recargar la IU."
	L.RELOAD =  "Recargar IU"
end

BINDING_HEADER_CODERUNNER = L.BINDING_HEADER
BINDING_NAME_CODERUNNER_TOGGLE = L.BINDING_NAME_TOGGLE

------------------------------------------------------------------------

local f = CreateFrame("Frame", ADDON, UIParent, "ButtonFrameTemplate")
f:SetPoint("TOPLEFT", 16, -116)
f:SetSize(800, 425)
f:Hide()

f:SetAttribute("UIPanelLayout-defined", true)
f:SetAttribute("UIPanelLayout-enabled", true)
f:SetAttribute("UIPanelLayout-area", "doublewide")
f:SetAttribute("UIPanelLayout-pushable", 3)
f:SetAttribute("UIPanelLayout-whileDead", true)
tinsert(UISpecialFrames, ADDON)

------------------------------------------------------------------------

function f:Load()
	-- use f instead of self because this is set as the cancel button OnClick script too
	f.EditBox:SetText(db[SELECTION] or "")
end

function f:Save()
	local text = strtrim(f.EditBox:GetText())
	db[SELECTION] = strlen(text) > 0 and text or nil
end

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function(self, event, addon)
	if event == "PLAYER_LOGIN" then
		db = CodeRunnerDB or {}
		CodeRunnerDB = db

		SELECTION = CodeRunnerSelection or UnitName("player")
		CodeRunnerSelection = SELECTION

		CodeRunnerFont = CodeRunnerFont or "Inconsolata"

		if not db[SELECTION] then
			db[SELECTION] = ""
		end

		if LSM then
			local path = "Interface\\AddOns\\"..ADDON.."\\Fonts\\"
			local hasCyrillic = bit.bor(LSM.LOCALE_BIT_western, LSM.LOCALE_BIT_ruRU)
			LSM:Register("font", "Cousine",     path.."Cousine.ttf",        hasCyrillic)
			LSM:Register("font", "Inconsolata", path.."InconsolataLGC.otf", hasCyrillic)
			function GetFontFile()
				return LSM:Fetch("font", CodeRunnerFont or "Inconsolata")
			end
		else
			local default = "Interface\\AddOns\\"..ADDON.."\\Fonts\\InconsolataLGC.ttf"
			function GetFontFile()
				return default
			end
		end
	else
		for k, v in pairs(db) do
			if v == "" then
				db[k] = nil
			end
		end
	end
end)

------------------------------------------------------------------------

f:SetScript("OnShow", function(f)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)

	f.TitleText:SetText(ADDON)
	SetPortraitToTexture(f.portrait, "Interface\\AddOns\\" .. ADDON .. "\\Portrait")

	local drag = CreateFrame("Button", nil, f)
	drag:SetPoint("TOPLEFT", CodeRunnerTitleBg, 40, 0)
	drag:SetPoint("BOTTOMRIGHT", CodeRunnerTitleBg)
	f.DragButton = drag

	drag:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 10)
		GameTooltip:SetText("Drag to move this frame.\nRight-click to reset its position.")
	end)
	drag:SetScript("OnLeave", GameTooltip_Hide)

	drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart", function(self)
		f:StartMoving()
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
	end)
	drag:SetScript("OnDragStop", function(self)
		f:StopMovingOrSizing()
		f.userPlaced = true
		if self:IsMouseOver() then
			self:GetScript("OnEnter")(self)
		end
	end)
	drag:SetScript("OnHide", function(self)
		f:StopMovingOrSizing()
	end)

	drag:RegisterForClicks("RightButtonUp")
	drag:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			f.userPlaced = false
			f:Hide()
			ShowUIPanel(f)
		end
	end)

	------------------------------------------------------------------------

	local scrollFrame = CreateFrame("ScrollFrame", "$parentScrollFrame", f)
	scrollFrame:SetPoint("TOPLEFT", 8, -64)
	scrollFrame:SetPoint("BOTTOMRIGHT", -32, 29)
	scrollFrame:SetClipsChildren(true)
	SCROLL_FRAME_HEIGHT = scrollFrame:GetHeight()
	f.ScrollFrame = scrollFrame

	local scrollBar = CreateFrame("Slider", "$parentScrollBar", f, "UIPanelScrollBarTemplate")
	scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 6, -16)
	scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 6, 16)
	scrollBar:SetScript("OnValueChanged", nil) -- remove default
	scrollBar:SetMinMaxValues(0, 1)
	scrollFrame.ScrollBar = scrollBar

	local scrollBarBG = scrollBar:CreateTexture(nil, "BACKGROUND")
	scrollBarBG:SetAllPoints(true)
	scrollBarBG:SetTexture(0,0,0,0.5)

	------------------------------------------------------------------------

	local focus

	local editBox = CreateFrame("EditBox", nil, scrollFrame)
	scrollFrame:SetScrollChild(editBox)
	editBox:SetPoint("TOP")
	editBox:SetPoint("LEFT")
	editBox:SetPoint("RIGHT")
	editBox:SetHeight(1000)
	editBox:SetFontObject(GameFontHighlight)
	editBox:SetFont(GetFontFile(), FONT_SIZE)
	editBox:SetTextColor(FONT_R, FONT_G, FONT_B)
	editBox:SetTextInsets(5,5,5,5)
	editBox:SetAutoFocus(false)
	editBox:SetMultiLine(true)
	f.EditBox = editBox

	editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
	editBox:SetScript("OnTabPressed", function(self) self:Insert("    ") end)
	editBox:SetScript("OnEditFocusGained", function(self) focus:Hide() end)
	editBox:SetScript("OnEditFocusLost", function(self)
		db[SELECTION] = self:GetText()
		focus:Show()
	end)
	editBox:SetScript("OnShow", function(self)
		f.TitleText:SetFormattedText("%s - %s", ADDON, SELECTION or UNKNOWN)
		self:SetText(db[SELECTION] or "")
		self:SetFocus()
	end)
	--[[
	local editBG = editBox:CreateTexture(nil, "BACKGROUND")
	editBG:SetAllPoints(true)
	editBG:SetTexture(0,1,0,0.1)
	]]
	focus = CreateFrame("Button", nil, scrollFrame)
	focus:SetAllPoints(true)
	focus:SetScript("OnClick", function(self) editBox:SetFocus() end)
	f.Focus = focus

	------------------------------------------------------------------------

	local function ScrollTo(v)
		offset = max(min(v, 0), maxOffset)
		scrollFrame:SetVerticalScroll(-offset)
		editBox:SetPoint("TOP", 0, offset)

		local perc = maxOffset == 0 and 0 or offset / maxOffset
		scrollBar:SetValue(perc)
		scrollBar.ScrollUpButton:SetEnabled(perc > 0.01)
		scrollBar.ScrollDownButton:SetEnabled(perc < 0.99)
	end

	editBox:SetScript("OnCursorChanged", function(self, x, y, width, height)
		LINE_HEIGHT = height
		if offset < y then
			ScrollTo(y)
		elseif floor(offset - SCROLL_FRAME_HEIGHT + height * 2) > y then
			local v = y + SCROLL_FRAME_HEIGHT - height * 2
			maxOffset = min(maxOffset, v)
			ScrollTo(v)
		end
	end)

	scrollFrame:UpdateScrollChildRect()

	scrollFrame:EnableMouseWheel(true)
	scrollFrame:SetScript("OnMouseWheel", function(self, delta)
		ScrollTo(offset + delta * LINE_HEIGHT * 3)
	end)

	scrollBar:EnableMouseWheel(true)
	scrollBar:SetScript("OnMouseWheel", function(self, delta)
		ScrollTo(offset + delta * LINE_HEIGHT * 3)
	end)

	scrollBar.ScrollUpButton:SetScript("OnClick", function()
		ScrollTo(offset + 1 * LINE_HEIGHT * 3)
	end)
	scrollBar.ScrollDownButton:SetScript("OnClick", function()
		ScrollTo(offset - 1 * LINE_HEIGHT * 3)
	end)

	-- #TODO fix scrollbar with small editbox heights

	------------------------------------------------------------------------

	local runButton = CreateFrame("Button", "$parentRunButton", f, "MagicButtonTemplate")
	runButton:SetPoint("BOTTOMRIGHT", -7, 5)
	runButton.RightSeparator:Hide()
	runButton:SetText(L.RUN)
	f.RunButton = runButton

	runButton:SetScript("OnClick", function()
		RunScript(editBox:GetText())
	end)

	------------------------------------------------------------------------

	local cancelButton = CreateFrame("Button", "$parentRevertButton", f, "MagicButtonTemplate")
	cancelButton:SetPoint("RIGHT", runButton, "LEFT")
	cancelButton.RightSeparator:Hide()
	cancelButton:SetText(L.REVERT)
	f.RevertButton = cancelButton

	------------------------------------------------------------------------

	local reloadButton = CreateFrame("Button", "$parentReloadButton", f, "MagicButtonTemplate")
	reloadButton:SetPoint("BOTTOMLEFT", 7, 5)
	reloadButton.LeftSeparator:Hide()
	reloadButton:SetText(L.RELOAD)
	reloadButton:SetWidth(max(110, reloadButton:GetFontString():GetStringWidth() + 28))
	f.ReloadButton = reloadButton

	------------------------------------------------------------------------

	local buttonWidth = max(110, reloadButton:GetFontString():GetStringWidth() + 28, cancelButton:GetFontString():GetStringWidth() + 28, runButton:GetFontString():GetStringWidth() + 28)
	reloadButton:SetWidth(buttonWidth)
	cancelButton:SetWidth(buttonWidth)
	runButton:SetWidth(buttonWidth)

	------------------------------------------------------------------------

	if LSM and LibStub("PhanxConfig-MediaDropdown", true) then
		local font = LibStub("PhanxConfig-MediaDropdown"):New(f, "Font", nil, "font")
		font:SetPoint("TOPRIGHT", -10, -15)
		font:SetWidth(200)
		f.fontMenu = font

		font.labelText:ClearAllPoints()
		font.labelText:SetPoint("BOTTOMRIGHT", font, "BOTTOMLEFT", -5, 5)

		function font:OnValueChanged(value, text)
			CodeRunnerFont = value
			editBox:SetFont(LSM:Fetch("font", value), FONT_SIZE, "")
		end

		font:SetValue(CodeRunnerFont)
	end

	------------------------------------------------------------------------

	-- Load saved code OnShow or on cancel
	f:Load()
	f:SetScript("OnShow", f.Load)
	cancelButton:SetScript("OnClick", f.Load)

	-- Save written code on hide or on reload
	f:SetScript("OnHide", f.Save)
	reloadButton:SetScript("OnClick", function()
		f:Save()
		ReloadUI()
	end)

end) -- f:OnShow

------------------------------------------------------------------------

SLASH_CODERUNNER1 = "/cr"
SLASH_CODERUNNER2 = "/code"
SLASH_CODERUNNER3 = "/coderunner"
SlashCmdList.CODERUNNER = function()
	if f.userPlaced then
		f:SetShown(not f:IsShown())
	elseif f:IsShown() then
		HideUIPanel(f)
	else
		ShowUIPanel(f)
	end
end

------------------------------------------------------------------------

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
if LDB then
	LDB:NewDataObject(ADDON, {
		type = "launcher",
		icon = "Interface\\AddOns\\"..ADDON.."\\Icon",
		OnClick = SlashCmdList.CODERUNNER,
	})
end
