-- FlyoutMenu.lua
SavedTargetName = ""
print(">> RaidTools: FlyoutMenu loaded")
local FlyoutMenu = CreateFrame("Frame", "RaidToolsFlyout", UIParent, "BackdropTemplate")
FlyoutMenu:SetSize(195, 405)
FlyoutMenu:SetPoint("CENTER")
FlyoutMenu:SetMovable(true)
FlyoutMenu:EnableMouse(true)
FlyoutMenu:RegisterForDrag("LeftButton")
FlyoutMenu:SetScript("OnDragStart", FlyoutMenu.StartMoving)
FlyoutMenu:SetScript("OnDragStop", FlyoutMenu.StopMovingOrSizing)

FlyoutMenu:SetBackdrop({
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
FlyoutMenu:SetBackdropColor(0, 0, 0, 0.8)
FlyoutMenu:Hide()

local header = FlyoutMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
header:SetPoint("TOPLEFT", 35, -10)
header:SetScale(1.2)
header:SetText("RaidTools Menu")

--------------------------------------------------
-- 📌 Dropdown for Addon Mode
--------------------------------------------------

local modeDropdown = CreateFrame("Frame", "RaidToolsModeDropdown", FlyoutMenu, "UIDropDownMenuTemplate")
modeDropdown:SetPoint("TOPLEFT", 0, -50)
modeDropdown:SetScript("OnEnter", function()
    GameTooltip:SetOwner(modeDropdown, "ANCHOR_RIGHT")
    GameTooltip:SetText("Change the addon mode", 1,1,1)
    GameTooltip:Show()
end)
modeDropdown:SetScript("OnLeave", GameTooltip_Hide)

local modes = { "None", "Silent", "My Group" }

-- Sync dropdown with current SavedVariables on load
local function SyncDropdownWithDB()
    local mode = _G.RaidToolsDB.currentMode or "None"
    UIDropDownMenu_SetText(modeDropdown, mode)
end

UIDropDownMenu_Initialize(modeDropdown, function(self, level)
    for _, mode in ipairs(modes) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = mode
        info.checked = _G.RaidToolsDB.currentMode == mode
        info.func = function()
            _G.RaidToolsDB.currentMode = mode
            _G.RaidToolsDB._modeConfirmed = true
            UIDropDownMenu_SetText(modeDropdown, mode)
            info.checked = true
            print(">> RaidTools mode changed to:", mode)
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)
-- Add label above dropdown
local dropdownLabel = FlyoutMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dropdownLabel:SetPoint("TOPLEFT", modeDropdown, "TOPLEFT", 15, 15)
dropdownLabel:SetText("Mode:")
-- Increase width for breathing room
UIDropDownMenu_SetWidth(modeDropdown, 145)
SyncDropdownWithDB()

--------------------------------------------------
-- 📋 Scrollable Blacklist + Strike Lists
--------------------------------------------------

local function CreateScrollList(parent, title, anchorY)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 10, anchorY)
    header:SetText(title)

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetSize(150, 90)  

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(150, 90)
    scrollFrame:SetScrollChild(content)

    content.lines = {}

    for i = 1, 10 do
        local line = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", 5, -((i - 1) * 14))
        line:SetText("")
        content.lines[i] = line
    end

    return content
end

local strikeContent = CreateScrollList(FlyoutMenu, "Strikes", -90)
local blacklistContent = CreateScrollList(FlyoutMenu, "Blacklist", -205)

function FlyoutMenu:UpdateLists(groupMembers, db)
    local blackListIndex, strikeIndex = 1, 1
    -- Clear old entries
    for i = 1, 10 do
        strikeContent.lines[i]:SetText("")
        strikeContent.lines[i]:Hide()
        blacklistContent.lines[i]:SetText("")
        blacklistContent.lines[i]:Hide()
    end

    -- Show group members with strikes
    for _, name in ipairs(groupMembers) do
        if _G.RaidToolsDB.strikes and _G.RaidToolsDB.strikes[name] then
            if strikeContent.lines[strikeIndex] then
                strikeContent.lines[strikeIndex]:SetText("• " .. name .. " (" .. _G.RaidToolsDB.strikes[name] .. ")")
                local color = (strikeIndex % 2 == 0) and {1, 0.82, 0} or {1, 1, 1}
                strikeContent.lines[strikeIndex]:SetTextColor(unpack(color))
                strikeContent.lines[strikeIndex]:Show()
                strikeIndex = strikeIndex + 1
            end
        end
        if _G.RaidToolsDB.blacklist and _G.RaidToolsDB.blacklist[name] then
            if blacklistContent.lines[blackListIndex] then
                blacklistContent.lines[blackListIndex]:SetText("• " .. name)
                local color = (blackListIndex % 2 == 0) and {1, 0.82, 0} or {1, 1, 1}
                blacklistContent.lines[blackListIndex]:SetTextColor(unpack(color))
                blacklistContent.lines[blackListIndex]:Show()
                blackListIndex = blackListIndex + 1
                local playerBListWarn = ">>RaidTools: " .. name .. " is on your Raid Tools BList."
                print(playerBListWarn)
                RaidNotice_AddMessage(RaidWarningFrame, playerBListWarn, { r = 1.0, g = 0.0, b = 0.0 }) -- red text, no sound

            end
        end
    end
end

--------------------------------------------------
-- 🎯 Player Target Block
--------------------------------------------------

local playerBlock = CreateFrame("Frame", nil, FlyoutMenu)
playerBlock:SetSize(160, 130)
playerBlock:SetPoint("TOPLEFT", blacklistContent, "BOTTOMLEFT", 10, -10)
playerBlock:Hide()

local nameBox = CreateFrame("EditBox", nil, playerBlock, "InputBoxTemplate")
nameBox:SetAutoFocus(false)
nameBox:SetSize(160, 20)
nameBox:SetPoint("TOP", 0, -5)

local warnButton = CreateFrame("Button", nil, playerBlock, "UIPanelButtonTemplate")
warnButton:SetSize(165, 20)
warnButton:SetText("Warn")
warnButton:SetNormalFontObject("GameFontHighlight")
warnButton:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", -5, -5)
warnButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(warnButton, "ANCHOR_RIGHT")
    GameTooltip:SetText("Warn this player (adds a strike)", 1,1,1)
    GameTooltip:Show()
end)
warnButton:SetScript("OnLeave", GameTooltip_Hide)
warnButton:SetScript("OnClick", function()
    if SavedTargetName and SavedTargetName ~= "" then
        RaidToolsUtils.AddStrike(SavedTargetName, true, false)
    end
end)

local kickButton = CreateFrame("Button", nil, playerBlock, "UIPanelButtonTemplate")
kickButton:SetSize(165, 20)
kickButton:SetText("Kick")
kickButton:SetNormalFontObject("GameFontHighlight")
kickButton:SetPoint("TOPLEFT", warnButton, "BOTTOMLEFT", 0, -5)
kickButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(kickButton, "ANCHOR_RIGHT")
    GameTooltip:SetText("Kick this player (adds to blacklist)", 1,1,1)
    GameTooltip:Show()
end)
kickButton:SetScript("OnLeave", GameTooltip_Hide)
kickButton:SetScript("OnClick", function()
    if SavedTargetName and SavedTargetName ~= "" then
        RaidToolsUtils.AddToBlacklist(SavedTargetName, true, true, false)
    end
end)

function FlyoutMenu:ShowPlayerBlock(targetName, inGroup)
    nameBox:SetText(targetName)
    playerBlock:Show()

    warnButton:SetShown(inGroup)
    kickButton:SetShown(inGroup)
    warnButton:Show()
    kickButton:Show()
end

function FlyoutMenu:HidePlayerBlock()
    playerBlock:Hide()
end

--------------------------------------------------
-- 🧠 Hook: Show Menu When Needed
--------------------------------------------------

function FlyoutMenu:Refresh(groupMembers, db, targetName, isTargetedPlayer)
    self:UpdateLists(groupMembers, db)
    SyncDropdownWithDB()
    SavedTargetName = targetName or ""
    if isTargetedPlayer then
        local inGroup = tContains(groupMembers, targetName)
        self:ShowPlayerBlock(targetName, inGroup)
    else
        self:HidePlayerBlock()
    end

    if IsInRaid() then
        self:Show()
    else
        self:Hide()
    end
    
end

--------------------------------------------------
-- 🛠 Export
--------------------------------------------------

_G.FlyoutMenu = FlyoutMenu