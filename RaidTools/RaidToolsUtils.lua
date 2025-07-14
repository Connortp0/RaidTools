local RaidToolsUtils = {}

-- List Functions
function RaidToolsUtils.AddToBlacklist(playerName)
    db.blacklist = db.blacklist or {}
    db.blacklist[playerName] = true
    SaveRaidToolsData()
    print(playerName .. " has been added to the blacklist.")
end

function RaidToolsUtils.RemoveFromBlacklist(playerName)
    if db.blacklist and db.blacklist[playerName] then
        db.blacklist[playerName] = nil
        SaveRaidToolsData()
        print("Removed " .. playerName .. " from blacklist.")
    end
end

function RaidToolsUtils.AddStrike(playerName)
    if RaidToolsUtils.IsBlacklisted(playerName) then
        print(playerName .. " is already blacklisted. Cannot add strike.")
    else
        db.strikes = db.strikes or {}
        db.strikes[playerName] = (db.strikes[playerName] or 0) + 1
        SaveRaidToolsData()
        print(playerName .. " has " .. db.strikes[playerName] .. " strike(s).")

        if db.strikes[playerName] >= 2 then
            RaidToolsUtils.AddToBlacklist(playerName)
            RaidToolsUtils.ClearStrikes(playerName)
            SaveRaidToolsData()
            print("Auto-blacklisted after 2 strikes.")
        end
    end
end

function RaidToolsUtils.ClearStrikes(playerName)
    if db.strikes[playerName] then
        db.strikes[playerName] = nil
        SaveRaidToolsData()
        print("Cleared strikes for " .. playerName)
    end
end

function RaidToolsUtils.IsBlacklisted(playerName)
    return db.blacklist and db.blacklist[playerName] == true
end

function RaidToolsUtils.GetStrikeCount(playerName)
    return db.strikes and db.strikes[playerName] or 0
end

-- Disciplinary Functions
function RaidToolsUtils.StrikeWarn(playerName, RaidWarning)
    RaidWarning = RaidWarning or false
    local chatType = "SAY" -- Default fallback
    if IsInRaid() then
        if RaidWarning then
            chatType = "RAID_WARNING"
        else
            chatType = "RAID"
        end
    elseif IsInGroup() then
        chatType = "PARTY"
    end
    
    if db._modeConfirmed and db.currentMode == "My Group" then
        SendChatMessage(">>RaidTools: " .. playerName .. " be careful what you do. We don't accept the following; Ninja looting, Abusing (Swearing at others and/or Trolling)", chatType)
        SendChatMessage("Failing to do mechanics or ignoring instructions after being warned WILL result in you being REPLACED.", chatType)
    end

    RaidToolsUtils.AddStrike(playerName)
end

function RaidToolsUtils.StrikeKick(playerName, RaidWarning)
    RaidWarning = RaidWarning or false
    local chatType = "SAY" -- Default fallback
    if IsInRaid() then
        if RaidWarning then
            chatType = "RAID_WARNING"
        else
            chatType = "RAID"
        end
    elseif IsInGroup() then
        chatType = "PARTY"
    end

    if db._modeConfirmed and db.currentMode == "My Group" then
        SendChatMessage(">>RaidTools: " .. playerName .. " has been kicked for repeated offenses. We don't accept the following; Ninja looting, Abusing (Swearing at others", chatType)
        SendChatMessage("and/or Trolling) Failing to do mechanics or ignoring instructions after being warned WILL result in you being REPLACED.", chatType)
    end

    RaidToolsUtils.AddStrike(playerName)
    -- May not work
    UninviteUnit(playerName)
end

-- Utility Functions

function RaidToolsUtils.GetCurrentGroupMembers()
    local groupMembers = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, realm = GetRaidRosterInfo(i)
            if realm == nil then
                realm = GetRealmName()
            end
            if name then
                local fullName = name .. "-" .. realm
                table.insert(groupMembers, fullName)
                print (">> RaidTools: Found group member:", fullName)
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local name, realm = UnitName("party" .. i)
            if realm == nil then
                realm = GetRealmName()
            end
            if name then
                local fullName = name .. "-" .. realm
                table.insert(groupMembers, fullName)
            end
        end
    else
        -- Add player’s own name too
        local name, realm = UnitName("player")
        local fullName = ""
        if realm == nil then
            realm = GetRealmName()
        end
        if name then
            fullName = name .. "-" .. realm
            table.insert(groupMembers, fullName)
        end
    end
    return groupMembers
end


_G.RaidToolsUtils = RaidToolsUtils
