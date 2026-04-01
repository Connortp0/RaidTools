-- RaidToolsUtils.lua
local RaidToolsUtils = {}
-- List Functions
function RaidToolsUtils.IsBlacklisted(playerName)
    return _G.RaidToolsDB.blacklist and _G.RaidToolsDB.blacklist[playerName] == true
end

function RaidToolsUtils.GetStrikeCount(playerName)
    return _G.RaidToolsDB.strikes and _G.RaidToolsDB.strikes[playerName] or 0
end

function RaidToolsUtils.AddToBlacklist(playerName, shouldRaidWarn, shouldKick, cmd)
    if RaidToolsUtils.IsBlacklisted(playerName) == false then
        RaidToolsUtils.ClearStrikes(playerName)
        _G.RaidToolsDB.blacklist[playerName] = true
        print("Added " .. playerName .. " to the blacklist.")

        if _G.RaidToolsDB._modeConfirmed == true and _G.RaidToolsDB.currentMode == "My Group" and cmd == false then
            local shouldRaidWarn = shouldRaidWarn or false
            local shouldKick = shouldKick or false
            local cmd = cmd or false
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
            if shouldKick and cmd == false then
                SendChatMessage(">>RaidTools: " .. playerName .. " has been kicked for repeated offenses. We don't accept the following; Ninja looting, Abusing (Swearing at others and/or Trolling)", chatType)
                SendChatMessage("Failing to do mechanics or ignoring instructions after being warned WILL result in you being REPLACED.", chatType)
            elseif cmd == false then
                SendChatMessage(">>RaidTools: " .. playerName .. " be careful what you do. We don't accept the following; Ninja looting, Abusing (Swearing at others and/or Trolling)", chatType)
                SendChatMessage("Failing to do mechanics or ignoring instructions after being warned WILL result in you being REPLACED.", chatType)
            end
        end
    else
        print(playerName .. " is already blacklisted.")
    end
end

function RaidToolsUtils.RemoveFromBlacklist(playerName)
    if RaidToolsUtils.IsBlacklisted(playerName) == true then
        _G.RaidToolsDB.blacklist[playerName] = nil
        print("Removed " .. playerName .. " from blacklist.")
    end
end

function RaidToolsUtils.AddStrike(playerName, shouldRaidWarn, cmd)
    if RaidToolsUtils.IsBlacklisted(playerName) == false then
            -- Increment the strike count
        _G.RaidToolsDB.strikes = _G.RaidToolsDB.strikes or {}
        _G.RaidToolsDB.strikes[playerName] = (_G.RaidToolsDB.strikes[playerName] or 0) + 1
        print("Added strike for " .. playerName .. ". Total strikes: " .. _G.RaidToolsDB.strikes[playerName])

        if _G.RaidToolsDB._modeConfirmed == true and _G.RaidToolsDB.currentMode == "My Group" and cmd == false then
            local shouldRaidWarn = shouldRaidWarn or false
            local cmd = cmd or false
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
            if _G.RaidToolsDB.strikes[playerName] == 1 and cmd == false then
                SendChatMessage(">>RaidTools: " .. playerName .. " be careful what you do. We don't accept the following; Ninja looting, Abusing (Swearing at others and/or Trolling)", chatType)
                SendChatMessage("Failing to do mechanics or ignoring instructions after being warned WILL result in you being REPLACED.", chatType)
            end
        end
        if _G.RaidToolsDB.strikes[playerName] >= 2 then
            RaidToolsUtils.AddToBlacklist(playerName, true, true, false)
            print("Auto-blacklisted after 2 strikes.")
        end
    else
        print(">>RaidTools: " .. playerName .. " is blacklisted. Cannot add strike.")
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
        local playerName, playerRealm = UnitName("player")
        if playerName then
            playerRealm = playerRealm or GetRealmName()
            table.insert(groupMembers, playerName .. "-" .. playerRealm)
        end

        for i = 1, 4 do
            local unitID = "party" .. i
            if UnitExists(unitID) then
                local name, realm = UnitName(unitID)
                if realm == nil then
                    realm = GetRealmName()
                end
                if name then
                    table.insert(groupMembers, name .. "-" .. realm)
                end
            end
        end
    end
    return groupMembers
end

function RaidToolsUtils.FindRaidUnit(charName)
    -- Loop through raid/party members to find matching name
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unitID = "raid" .. i
            local name = UnitName(unitID)

            if name and name == charName then
                return unitID
            end
        end
    elseif IsInGroup() then
        local name = UnitName("player")
        if name and name == charName then
            return "player"
        end

        for i = 1, 4 do
            local unitID = "party" .. i
            if UnitExists(unitID) then
                local name = UnitName(unitID)
                if name and name == charName then
                    return unitID
                end
            end
        end
    end

    -- Return nil if no match found
    return nil
end

function RaidToolsUtils.CanUseMyGroupMode()
    if IsInRaid() then
        return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
    elseif IsInGroup() then
        return UnitIsGroupLeader("player")
    end
    return true
end

_G.RaidToolsUtils = RaidToolsUtils
