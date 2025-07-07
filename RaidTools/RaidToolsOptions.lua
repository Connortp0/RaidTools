-- RaidToolsOptions.lua

-- Create an options panel
local optionsPanel = CreateFrame("Frame", "RaidToolsOptionsPanel", InterfaceOptionsFramePanelContainer)
optionsPanel.name = "RaidTools"

-- Create a title for the panel
local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("RaidTools " .. C_AddOns.GetAddOnMetadata("RaidTools", "Version"))

-- List Section
local listSection = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
listSection:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
listSection:SetText("List")

local playerList = {}

-- Search Box
local searchBox = CreateFrame("EditBox", nil, optionsPanel, "InputBoxTemplate")
searchBox:SetPoint("TOPLEFT", listSection, "BOTTOMLEFT", 0, -10)
searchBox:SetSize(200, 20)
searchBox:SetAutoFocus(false)

-- Scrollable frame to display player names and realms
local scrollFrame = CreateFrame("ScrollFrame", "PlayerListScrollFrame", optionsPanel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -10)
scrollFrame:SetSize(400, 150)

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(200, #playerList * 20)

-- Display total player count
local totalCountLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
totalCountLabel:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 0, -10)
totalCountLabel:SetText("Total Players: " .. #playerList)

-- Input box for player name-realm
local playerNameRealmInput = CreateFrame("EditBox", nil, optionsPanel, "InputBoxTemplate")
playerNameRealmInput:SetPoint("TOPLEFT", totalCountLabel, "BOTTOMLEFT", 0, -10)
playerNameRealmInput:SetSize(200, 20)
playerNameRealmInput:SetAutoFocus(false)

-- Add Player button
local buttonAdd = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
buttonAdd:SetPoint("TOPLEFT", playerNameRealmInput, "BOTTOMLEFT", 0, -10)
buttonAdd:SetSize(100, 20)
buttonAdd:SetText("Add Player")

scrollFrame:SetScrollChild(scrollChild)

-- Register the options panel
local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, "RaidTools")
Settings.RegisterAddOnCategory(category)

-- Table to store labels and buttons
local playerLabels = {}
local removeButtons = {}

-- Function to update the player list
function updatePlayerList()
    playerList = {}

    for playerNameRealm, _ in pairs(_G.BList) do
        local name, realm = string.match(playerNameRealm, "(.*)-(.*)")
        table.insert(playerList, {name = name, realm = realm, fullName = playerNameRealm})
    end

    scrollChild:SetSize(200, #playerList * 20)

    -- Remove old labels and buttons
    for _, label in ipairs(playerLabels) do label:Hide() end
    for _, button in ipairs(removeButtons) do button:Hide() end

    playerLabels, removeButtons = {}, {}

    -- Create new labels and buttons
    for i, playerData in ipairs(playerList) do
        local playerLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        playerLabel:SetPoint("TOPLEFT", 10, -20 * (i - 1))
        playerLabel:SetText(playerData.fullName)
        playerLabel:Show()
        table.insert(playerLabels, playerLabel)

        local buttonRemove = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
        buttonRemove:SetPoint("TOPLEFT", playerLabel, "TOPRIGHT", 10, 0)
        buttonRemove:SetSize(100, 20)
        buttonRemove:SetText("Remove")
        buttonRemove:SetScript("OnClick", function()
            if _G.BList[playerData.fullName] then
                _G.BList[playerData.fullName] = nil
                print(">>RaidTools: " .. playerData.fullName .. " removed.")
                saveBList()
            end
        end)
        buttonRemove:Show()
        table.insert(removeButtons, buttonRemove)
    end

    totalCountLabel:SetText("Total Players: " .. #playerList)
end

-- Add Player functionality
buttonAdd:SetScript("OnClick", function()
    local playerNameRealm = playerNameRealmInput:GetText()
    local name, realm = string.match(playerNameRealm, "(.*)-(.*)")

    if name and realm then
        if not _G.BList[playerNameRealm] then
            _G.BList[playerNameRealm] = true
            print(">>RaidTools: " .. playerNameRealm .. " added.")
            saveBList()
        else
            print(">>RaidTools: " .. playerNameRealm .. " is already in the list.")
        end
    else
        print("Please enter a Name-Realm.")
    end

    playerNameRealmInput:SetText("")
end)

-- Search functionality
searchBox:SetScript("OnTextChanged", function(self)
    if not playerLabels then return end

    local searchText = self:GetText():lower()
    for _, label in ipairs(playerLabels) do label:Hide() end
    for _, button in ipairs(removeButtons) do button:Hide() end

    playerLabels, removeButtons = {}, {}
    local visibleCount = 0

    for _, playerData in ipairs(playerList) do
        if playerData.fullName:lower():find(searchText) then
            local playerLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            playerLabel:SetPoint("TOPLEFT", 10, -20 * visibleCount)
            playerLabel:SetText(playerData.fullName)
            playerLabel:Show()
            table.insert(playerLabels, playerLabel)

            local buttonRemove = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
            buttonRemove:SetPoint("TOPLEFT", playerLabel, "TOPRIGHT", 10, 0)
            buttonRemove:SetSize(100, 20)
            buttonRemove:SetText("Remove")
            buttonRemove:SetScript("OnClick", function()
                _G.BList[playerData.fullName] = nil
                print(">>RaidTools: " .. playerData.fullName .. " removed.")
                saveBList()
            end)
            buttonRemove:Show()
            table.insert(removeButtons, buttonRemove)

            visibleCount = visibleCount + 1
        end
    end

    scrollChild:SetSize(200, visibleCount * 20)
end)