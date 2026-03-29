-- ModeSelector.lua

print(">> RaidTools: ModeSelector loaded")
local ModeSelector = {}

local modePopup = CreateFrame("Frame", "RaidToolsModePopup", UIParent, "BackdropTemplate")
modePopup:SetSize(220, 120)
modePopup:SetPoint("CENTER")
modePopup:SetBackdrop({
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
modePopup:SetBackdropColor(0, 0, 0, 0.8)
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
    button:SetNormalFontObject("GameFontHighlight")
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText("Change the addon mode", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnClick", function()
        ModeSelector:SetMode(label)
    end)
    return button
end

CreateModeButton("None", -5)
CreateModeButton("Silent", -35)
local myGroupButton = CreateModeButton("My Group", -65)
if not RaidToolsUtils.CanUseMyGroupMode() then
    myGroupButton:Hide()
end

--------------------------------------------------
-- ⚙️ Mode Logic
--------------------------------------------------

function ModeSelector:SetMode(mode)
    if mode == "My Group" and not RaidToolsUtils.CanUseMyGroupMode() then
        print(">>RaidTools: Only raid leader or assistant can use My Group mode.")
        _G.RaidToolsDB.currentMode = "None"
        _G.RaidToolsDB._modeConfirmed = true
        RefreshRTSystem()
        return
    end

    modePopup:Hide()
    _G.RaidToolsDB.currentMode = mode
    _G.RaidToolsDB._modeConfirmed = true
    print(">> RaidTools mode set to:", mode)
    RefreshRTSystem()
end

function ModeSelector:Show()
    if myGroupButton then
        local inLFG = false
        if C_LFGInfo and type(C_LFGInfo.IsInLFGDungeon) == "function" then
            inLFG = C_LFGInfo.IsInLFGDungeon()
        end
        myGroupButton:SetShown(RaidToolsUtils.CanUseMyGroupMode() and not inLFG)
    end
    modePopup:Show()
end

function ModeSelector:PromptIfNeeded()
    if IsInGroup() == true and _G.RaidToolsDB._modeConfirmed == false then
        ModeSelector:Show()
    end
end

--------------------------------------------------
-- 🛠 Export Module
--------------------------------------------------

_G.ModeSelector = ModeSelector
