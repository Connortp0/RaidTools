-- FlyoutMenu.lua

print(">> RaidTools: FlyoutMenu loaded")

local FlyoutMenu = CreateFrame("Frame", "RaidToolsFlyout", UIParent, "BackdropTemplate")
FlyoutMenu:SetSize(180, 280)
FlyoutMenu:SetPoint("CENTER")
FlyoutMenu:SetMovable(true)
FlyoutMenu:EnableMouse(true)
FlyoutMenu:RegisterForDrag("LeftButton")
FlyoutMenu:SetScript("OnDragStart", FlyoutMenu.StartMoving)
FlyoutMenu:SetScript("OnDragStop", FlyoutMenu.StopMovingOrSizing)

FlyoutMenu:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
FlyoutMenu:SetBackdropColor(0, 0, 0, 0.8)
FlyoutMenu:Hide()

--------------------------------------------------
-- 📌 Dropdown for Addon Mode
--------------------------------------------------

local modeDropdown = CreateFrame("Frame", "RaidToolsModeDropdown", FlyoutMenu, "UIDropDownMenuTemplate")
modeDropdown:SetPoint("TOPLEFT", 10, -10)

local modes = { "None", "Silent", "My Group" }

-- Sync dropdown with current SavedVariables on load
local function SyncDropdownWithDB()
    local mode = db.currentMode or "None"
    UIDropDownMenu_SetText(modeDropdown, mode)
end

UIDropDownMenu_Initialize(modeDropdown, function(self, level)
    for _, mode in ipairs(modes) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = mode
        info.func = function()
            db.currentMode = mode
            db._modeConfirmed = true
            UIDropDownMenu_SetText(modeDropdown, mode)
            print(">> RaidTools mode changed to:", mode)
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

UIDropDownMenu_SetWidth(modeDropdown, 100)
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
    scrollFrame:SetSize(150, 60) -- Shows ~3 players max

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(150, 60)
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

local strikeContent = CreateScrollList(FlyoutMenu, "Strikes", -40)
local blacklistContent = CreateScrollList(FlyoutMenu, "Blacklist", -115)

function FlyoutMenu:UpdateLists(groupMembers, db)
    local blackListIndex, strikeIndex = 1, 1
    for i = 1, 10 do
        if strikeContent.lines[i] then
            strikeContent.lines[i]:SetText("")
            strikeContent.lines[i]:Hide()
        end
        if blacklistContent.lines[i] then
            blacklistContent.lines[i]:SetText("")
            blacklistContent.lines[i]:Hide()
        end
    end
    for _, name in ipairs(groupMembers) do
        if db.strikes[name] and strikeContent.lines[strikeIndex] then
            strikeContent.lines[strikeIndex]:SetText("• " .. name .. " (" .. db.strikes[name] .. ")")
            strikeContent.lines[strikeIndex]:Show()
            strikeIndex = strikeIndex + 1
        end
        if db.blacklist[name] and blacklistContent.lines[blackListIndex] then
            blacklistContent.lines[blackListIndex]:SetText("• " .. name)
            blacklistContent.lines[blackListIndex]:Show()
            blackListIndex = blackListIndex + 1
        end
    end
end

--------------------------------------------------
-- 🎯 Player Target Block
--------------------------------------------------

local playerBlock = CreateFrame("Frame", nil, FlyoutMenu)
playerBlock:SetSize(160, 130)
playerBlock:SetPoint("TOPLEFT", blacklistContent, "BOTTOMLEFT", 0, -10)
playerBlock:Hide()

local nameBox = CreateFrame("EditBox", nil, playerBlock, "InputBoxTemplate")
nameBox:SetAutoFocus(false)
nameBox:SetEnabled(false)
nameBox:SetSize(150, 20)
nameBox:SetPoint("TOP", 0, -5)

local warnButton = CreateFrame("Button", nil, playerBlock, "UIPanelButtonTemplate")
warnButton:SetSize(150, 20)
warnButton:SetText("Warn")
warnButton:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -5)
warnButton:SetScript("OnClick", function()
    local targetName = nameBox:GetText()
    if targetName and targetName ~= "" then
        RaidToolsUtils.StrikeWarn(targetName, true)
    end
end)

local kickButton = CreateFrame("Button", nil, playerBlock, "UIPanelButtonTemplate")
kickButton:SetSize(150, 20)
kickButton:SetText("Kick")
kickButton:SetPoint("TOPLEFT", warnButton, "BOTTOMLEFT", 0, -5)
kickButton:SetScript("OnClick", function()
    local targetName = nameBox:GetText()
    if targetName and targetName ~= "" then
        RaidToolsUtils.StrikeKick(targetName, true)
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

    if isTargetedPlayer then
        local inGroup = tContains(groupMembers, targetName)
        self:ShowPlayerBlock(targetName, inGroup)
    else
        self:HidePlayerBlock()
    end

    if IsInRaid() or IsInGroup() then
        self:Show()
    else
        self:Hide()
    end
    
end

--------------------------------------------------
-- 🛠 Export
--------------------------------------------------

_G.FlyoutMenu = FlyoutMenu