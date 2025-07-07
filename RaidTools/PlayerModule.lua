-- PlayerModule.lua

local fullName = ""
local memberfullName = ""

-- Create a frame for your menu
local myMenuFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
myMenuFrame:SetSize(135, 135) -- Adjust the height as needed
myMenuFrame:Hide() -- Initially hide the menu

-- Set a solid black background color for the menu
myMenuFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
myMenuFrame:SetBackdropColor(0, 0, 0, .5)

-- Position the menu relative to the cursor
local function UpdateMenuPosition()
    local x, y = GetCursorPosition()
    myMenuFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y) -- Adjust the position as needed
end

-- Create a font string for the text above the buttons
local nameRealmEditBox = CreateFrame("EditBox", nil, myMenuFrame, "InputBoxTemplate")
nameRealmEditBox:SetPoint("TOP", myMenuFrame, "TOP", 0, -5) -- Position the text above the buttons
nameRealmEditBox:SetSize(100, 20)
nameRealmEditBox:SetAutoFocus(false)  -- Disable auto-focus
nameRealmEditBox:SetScript("OnEnterPressed", function(self) nameRealmEditBox:ClearFocus() end)  -- Clear focus on Enter
nameRealmEditBox:SetScript("OnEscapePressed", function(self) nameRealmEditBox:ClearFocus() end)  -- Clear focus on Escape

-- Create a font string for the text above the buttons
local statusText = myMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetPoint("TOP", myMenuFrame, "TOP", 0, -30) -- Position the text above the buttons

-- Create a font string for the text above the buttons
local statusText = myMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetPoint("TOP", myMenuFrame, "TOP", 0, -30) -- Position the text above the buttons

-- Create buttons
local button2 = CreateFrame("Button", nil, myMenuFrame, "UIPanelButtonTemplate")
button2:SetPoint("TOPLEFT", 18, -45)
button2:SetSize(100, 20)
button2:SetText("Normal Warn")

local button3 = CreateFrame("Button", nil, myMenuFrame, "UIPanelButtonTemplate")
button3:SetPoint("TOPLEFT", 18, -65)
button3:SetSize(100, 20)
button3:SetText("Loud Warn")

local button4 = CreateFrame("Button", nil, myMenuFrame, "UIPanelButtonTemplate")
button4:SetPoint("TOPLEFT", 18, -85)
button4:SetSize(100, 20)
button4:SetText("Add to BList")

local button5 = CreateFrame("Button", nil, myMenuFrame, "UIPanelButtonTemplate")
button5:SetPoint("TOPLEFT", 18, -105)
button5:SetSize(100, 20)
button5:SetText("Kick Player")

-- Function to update button visibility
local function UpdateButtonVisibility()
    -- Hide the Loud Warn button if in a party, show if in a raid
    if IsInRaid() then
        button3:Show()  -- Show the button in a raid
        myMenuFrame:SetSize(135, 135)
        button4:SetPoint("TOPLEFT", 18, -85)
        button5:SetPoint("TOPLEFT", 18, -105)

    elseif IsInGroup() then
        button3:Hide()  -- Hide the button in a party
        myMenuFrame:SetSize(135, 115)
        button4:SetPoint("TOPLEFT", 18, -65)
        button5:SetPoint("TOPLEFT", 18, -85)
    end
end

-- Set an OnClick handler for button2
button2:SetScript("OnClick", function(self)
    button2:SetScript("OnClick", function(self)
        local chatType = "SAY" -- Default fallback
        if IsInRaid() then
            chatType = "RAID"
        elseif IsInGroup() then
            chatType = "PARTY"
        end
    
        SendChatMessage(">>RaidTools: " .. fullName .. " be careful what you do. We don't accept the following; Ninja looting, Abusing (Swearing at others and/or Trolling)", chatType)
        SendChatMessage("Failing to do mechanics or ignoring instructions after being warned WILL result in you being REPLACED.", chatType)
    end)    
end)

-- Set an OnClick handler for button3
button3:SetScript("OnClick", function(self)
    SendChatMessage(">>RaidTools: " .. fullName .. " be careful what you do we don't accept the following; Ninja looting, Abusing (Swearing at others and/or Trolling)", "RAID_WARNING")
    SendChatMessage("Failing to do mechanics or something after being asked, next time WILL result in you being REPLACED.", "RAID_WARNING")
end)

-- Set an OnClick handler for button4
button4:SetScript("OnClick", function(self)
    -- Add to blacklist functionality here
end)

-- Set an OnClick handler for button5
button5:SetScript("OnClick", function(self)
    -- Kick player functionality here
end)

-- Register the PLAYER_LOGIN event to initialize
local function OnPlayerLogin()
    -- Iterate the player list and show how many are loaded
    local count = 0
    for _ in pairs(BList) do
        count = count + 1
    end
    print(">>RaidTools: Player Module Loaded with " .. count .. " players.")
    updatePlayerList()

    -- Update button visibility based on the current group status
    UpdateButtonVisibility()
end

-- This function is called when a new unit is targeted
local function OnPlayerTargetChanged()
    if not InCombatLockdown() then
        local chatType = "RAID_WARNING" -- Default to RAID_WARNING
        if IsInRaid() then
            chatType = "RAID_WARNING"  -- Send in Raid Warning if in a Raid
        elseif IsInGroup() then
            chatType = "PARTY"  -- Send in Party chat if in a Party
        end
        if UnitIsPlayer("target") and IsShiftKeyDown() then
            UpdateMenuPosition()
            local name, realm = UnitName("target")
            if realm == nil then
                realm = GetRealmName()
            end
            fullName = name .. "-" .. realm
            nameRealmEditBox:SetText(fullName) -- Update the text with the player's name
            if _G.BList[fullName] then
                statusText:SetText("!Bad!")
                button4:SetText("Remove from BList")
                button4:SetScript("OnClick", function(self)
                    _G.BList[fullName] = nil
                    print(">>RaidTools: " .. fullName .. " removed from your BList.")
                    saveBList()
                    OnPlayerTargetChanged()
                end)
                button5:SetScript("OnClick", function(self)
                    SendChatMessage(">>RaidTools: " .. fullName .. ", sorry but you are already on my Raid Tools Addon BList, you are probably on this list for one of these reasons;", chatType)
                    SendChatMessage("Ninja looting, Abusing (Swearing at others and/or Trolling), Failing to do mechanics or something after being asked.", chatType)
                end)
            else
                statusText:SetText("Fine")
                button4:SetText("Add to BList")
                button4:SetScript("OnClick", function(self)
                    _G.BList[fullName] = true
                    print(">>RaidTools: " .. fullName .. " added to your BList.")
                    saveBList()
                    OnPlayerTargetChanged()
                end)
                button5:SetScript("OnClick", function(self)
                    _G.BList[fullName] = true
                    print(">>RaidTools: " .. fullName .. " added to the list.")
                    saveBList()
                    OnPlayerTargetChanged()
                    SendChatMessage(">>RaidTools: " .. fullName .. " was kicked for one of the following; Ninja looting, Abusing (Swearing at others and/or Trolling),", chatType)
                    SendChatMessage("Failing to do mechanics or something after being asked. I have put them on my RaidTools BList.", chatType)
                end)
            end
            myMenuFrame:Show() -- Show the menu when a player is targeted and Shift is held
        else
            myMenuFrame:Hide() -- Hide the menu otherwise
        end
    else
        myMenuFrame:Hide() -- Hide the menu during combat lockdown
    end
end

local function OnGroupRosterUpdate()
    -- Call the update function to check if we are in a raid or party
    UpdateButtonVisibility()

    local numGroupMembers = GetNumGroupMembers()
    local unitPrefix = IsInRaid() and "raid" or "party"

    for i = 1, numGroupMembers do
        local unitID = unitPrefix .. i
        local memberName, memberRealm = UnitName(unitID)
        if memberName then
            if memberRealm == nil then
                memberRealm = GetRealmName()
            end
            local memberfullName = memberName .. "-" .. memberRealm
            if _G.BList[memberfullName] then
                local playerBListWarn = ">>RaidTools: " .. memberfullName .. " is on your Raid Tools BList."
                print(playerBListWarn)
                RaidNotice_AddMessage(RaidWarningFrame, playerBListWarn, ChatTypeInfo["RAID_WARNING"])
            end
        end
    end
end

local function OnPlayerLogout()
    saveBList()
end

-- Register the PLAYER_TARGET_CHANGED event
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    elseif event == "PLAYER_TARGET_CHANGED" then
        OnPlayerTargetChanged()
    elseif event == "GROUP_ROSTER_UPDATE" then
        OnGroupRosterUpdate()
    elseif event == "PLAYER_LOGOUT" then
        OnPlayerLogout()
    end
end)
