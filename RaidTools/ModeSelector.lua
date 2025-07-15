-- ModeSelector.lua

print(">> RaidTools: ModeSelector loaded")
local ModeSelector = {}

local modePopup = CreateFrame("Frame", "RaidToolsModePopup", UIParent, "BackdropTemplate")
modePopup:SetSize(260, 140)
modePopup:SetPoint("CENTER")
modePopup:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
modePopup:SetBackdropColor(0, 0, 0, 0.85)
modePopup:Hide()

--------------------------------------------------
-- 🗨️ Mode Text
--------------------------------------------------

local modeText = modePopup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
modeText:SetPoint("TOP", 0, -10)
modeText:SetText("Select RaidTools Mode:")

--------------------------------------------------
-- 🔘 Button Factory
--------------------------------------------------

local function CreateModeButton(label, offsetY)
    local button = CreateFrame("Button", nil, modePopup, "UIPanelButtonTemplate")
    button:SetSize(180, 24)
    button:SetText(label)
    button:SetPoint("TOP", modeText, "BOTTOM", 0, offsetY)
    button:SetScript("OnClick", function()
        ModeSelector:SetMode(label)
    end)
end

CreateModeButton("None", -25)
CreateModeButton("Silent", -55)
CreateModeButton("My Group", -85)

--------------------------------------------------
-- ⚙️ Mode Logic
--------------------------------------------------

function ModeSelector:SetMode(mode)
    modePopup:Hide()
    _G.RaidToolsDB.currentMode = mode
    _G.RaidToolsDB._modeConfirmed = true
    print(">> RaidTools mode set to:", mode)
    RefreshRTSystem()
end

function ModeSelector:Show()
    modePopup:Show()
end

function ModeSelector:PromptIfNeeded()
    if (IsInGroup() == true or IsInRaid() == true) and _G.RaidToolsDB._modeConfirmed == false then
        ModeSelector:Show()
    end
end

--------------------------------------------------
-- 🛠 Export Module
--------------------------------------------------

_G.ModeSelector = ModeSelector
