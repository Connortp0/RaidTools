local RaidToolsUtils = {}
-- List Functions
function RaidToolsUtils.IsBlacklisted(playerName)
    return _G.RaidToolsDB.blacklist and _G.RaidToolsDB.blacklist[playerName] == true
end

function RaidToolsUtils.GetStrikeCount(playerName)
    return _G.RaidToolsDB.strikes and _G.RaidToolsDB.strikes[playerName] or 0
end

function RaidToolsUtils.AddToBlacklist(playerName, shouldRaidWarn, shouldKick)
    if RaidToolsUtils.IsBlacklisted(playerName) == false then
        RaidToolsUtils.ClearStrikes(playerName)
        _G.RaidToolsDB.blacklist[playerName] = true
        print("Added " .. playerName .. " to the blacklist.")
    end
    if _G.RaidToolsDB._modeConfirmed == true and _G.RaidToolsDB.currentMode == "My Group" then
        shouldRaidWarn = shouldRaidWarn or false
        shouldKick = shouldKick or false
        local chatType = "SAY" -- Default fallback
        if IsInRaid() then
            if shouldRaidWarn then
                chatType = "RAID_WARNING"
            else
                chatType = "RAID"
            end
        elseif IsInGroup() then
            chatType = "PARTY"
        end
        if shouldKick then
            SendChatMessage(">>RaidTools: " .. playerName .. " has been kicked for repeated offenses. We don't accept the following; Ninja looting, Abusing (Swearing at others and/or Trolling)", chatType)
            SendChatMessage("Failing to do mechanics or ignoring instructions after being warned WILL result in you being REPLACED.", chatType)
            UninviteUnit(playerName)
        else
            SendChatMessage(">>RaidTools: " .. playerName .. " be careful what you do. We don't accept the following; Ninja looting, Abusing (Swearing at others and/or Trolling)", chatType)
            SendChatMessage("Failing to do mechanics or ignoring instructions after being warned WILL result in you being REPLACED.", chatType)
        end
    end
end

function RaidToolsUtils.RemoveFromBlacklist(playerName)
    if RaidToolsUtils.IsBlacklisted(playerName) == true then
        _G.RaidToolsDB.blacklist[playerName] = nil
        print("Removed " .. playerName .. " from blacklist.")
    end
end

function RaidToolsUtils.AddStrike(playerName, shouldRaidWarn)
    _G.RaidToolsDB.strikes = _G.RaidToolsDB.strikes or {}
    _G.RaidToolsDB.strikes[playerName] = (_G.RaidToolsDB.strikes[playerName] or 0) + 1
    print("Added strike for " .. playerName .. ". Total strikes: " .. _G.RaidToolsDB.strikes[playerName])

    if _G.RaidToolsDB._modeConfirmed == true and _G.RaidToolsDB.currentMode == "My Group" then
        shouldRaidWarn = shouldRaidWarn or false
        local chatType = "SAY" -- Default fallback
        if IsInRaid() then
            if shouldRaidWarn then
                chatType = "RAID_WARNING"
            else
                chatType = "RAID"
            end
        elseif IsInGroup() then
            chatType = "PARTY"
        end
        if _G.RaidToolsDB.strikes[playerName] == 1 then
            SendChatMessage(">>RaidTools: " .. playerName .. " be careful what you do. We don't accept the following; Ninja looting, Abusing (Swearing at others and/or Trolling)", chatType)
            SendChatMessage("Failing to do mechanics or ignoring instructions after being warned WILL result in you being REPLACED.", chatType)
        end
    end

    if _G.RaidToolsDB.strikes[playerName] >= 2 then
        RaidToolsUtils.AddToBlacklist(playerName, true, true)
        print("Auto-blacklisted after 2 strikes.")
    end
end

function RaidToolsUtils.ClearStrikes(playerName)
    if _G.RaidToolsDB.strikes[playerName] then
        _G.RaidToolsDB.strikes[playerName] = nil
        print("Cleared strikes for " .. playerName)
    end
end

-- Utility Functions

function RaidToolsUtils.GetCurrentGroupMembers()
    local groupMembers = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, realm = UnitName("raid" .. i)
            if realm == nil then
                realm = GetRealmName()
            end
            if name then
                local fullName = name .. "-" .. realm
                table.insert(groupMembers, fullName)
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
