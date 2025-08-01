print(">> RaidTools: LootTracker loaded")
local LootTracker = {}

local CURRENT_SEASON = 2 -- Or use timestamp markers

-- 📊 Track Rankings and Max Item Levels
local TRACK_ORDER = {
    ["Explorer"] = 1, ["Adventurer"] = 2,
    ["Veteran"] = 3, ["Champion"] = 4,
    ["Hero"] = 5, ["Myth"] = 6
}

local TRACK_MAX_ILVL = {
    ["Explorer"] = 619, ["Adventurer"] = 632,
    ["Veteran"] = 662, ["Champion"] = 658,
    ["Hero"] = 671, ["Myth"] = 684
}

-- 🔍 Tooltip Parsers
local function GetUpgradeTrack(itemLink)
    local tooltip = CreateFrame("GameTooltip", "LootTrackerTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)

    print(">> DEBUG: Scanning upgrade track for item = " .. tostring(itemLink))

    for i = 1, tooltip:NumLines() do
        local line = _G["LootTrackerTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text then
            print(">> DEBUG: Tooltip line " .. i .. ": " .. text)
            for track in pairs(TRACK_ORDER) do
                if text:find(track) then
                    print(">> DEBUG: Found upgrade track = " .. track)
                    return track
                end
            end
        end
    end

    print(">> DEBUG: No upgrade track detected.")
    return nil
end

local function GetItemSeason(itemLink)
    local tooltip = CreateFrame("GameTooltip", "LootTrackerSeasonTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)

    print(">> DEBUG: Scanning season info for item = " .. tostring(itemLink))

    for i = 1, tooltip:NumLines() do
        local line = _G["LootTrackerSeasonTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text then
            print(">> DEBUG: Tooltip line " .. i .. ": " .. text)
            local season = text:match("Season (%d+)")
            if season then
                print(">> DEBUG: Found season = " .. season)
                return tonumber(season)
            end
        end
    end

    print(">> DEBUG: No season detected. Using CURRENT_SEASON = " .. tostring(CURRENT_SEASON))
    return CURRENT_SEASON
end

local function GetItemLevel(itemLink)
    local tooltip = CreateFrame("GameTooltip", "LootTrackerILVLTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)

    print(">> DEBUG: Scanning item level for item = " .. tostring(itemLink))

    for i = 1, tooltip:NumLines() do
        local line = _G["LootTrackerILVLTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text then
            print(">> DEBUG: Tooltip line " .. i .. ": " .. text)
            local ilvl = text:match("Item Level (%d+)")
            if ilvl then
                print(">> DEBUG: Found item level = " .. ilvl)
                return tonumber(ilvl)
            end
        end
    end

    print(">> DEBUG: No item level detected.")
    return nil
end

local function IsCrafted(itemLink)
    local tooltip = CreateFrame("GameTooltip", "LootTrackerCraftedTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)

    print(">> DEBUG: Scanning for 'crafted' keyword in item = " .. tostring(itemLink))

    for i = 1, tooltip:NumLines() do
        local line = _G["LootTrackerCraftedTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text then
            print(">> DEBUG: Tooltip line " .. i .. ": " .. text)
            if text:lower():find("crafted") then
                print(">> DEBUG: Match found — item is crafted.")
                return true
            end
        end
    end

    print(">> DEBUG: No crafted keyword found — item is not crafted.")
    return false
end

-- 🧠 Determine Which Gear Slots to Check
local function ResolveSlots(itemLink)
    local itemType = GetItemType(itemLink)
    print(">> DEBUG: Item type resolved as: " .. tostring(itemType))

    if not itemType then
        print(">> DEBUG: No item type detected. Defaulting to ring slot (11).")
        return {11}
    end

    local slotMap = {
        ["INVTYPE_FINGER"]         = {11, 12},
        ["INVTYPE_TRINKET"]        = {13, 14},
        ["INVTYPE_WEAPON"]         = {16},
        ["INVTYPE_2HWEAPON"]       = {16},
        ["INVTYPE_WEAPONMAINHAND"] = {16},
        ["INVTYPE_WEAPONOFFHAND"]  = {17},
        ["INVTYPE_SHIELD"]         = {17},
        ["INVTYPE_HOLDABLE"]       = {17}
    }

    local slots = slotMap[itemType]
    if slots then
        print(">> DEBUG: Mapped slot(s): " .. table.concat(slots, ", "))
        return slots
    end

    local fallback = GetEquipmentSlotForItem(itemLink) or 11
    print(">> DEBUG: No direct mapping. Fallback slot resolved as: " .. tostring(fallback))
    return {fallback}
end

-- 🔍 Parse Equipment Slot from Tooltip (Fallback)
function GetEquipmentSlotForItem(itemLink)
    local slotKeywords = {
        ["Head"] = 1, ["Neck"] = 2, ["Shoulder"] = 3, ["Back"] = 15,
        ["Chest"] = 5, ["Wrist"] = 9, ["Hands"] = 10,
        ["Waist"] = 6, ["Legs"] = 7, ["Feet"] = 8,
        ["Finger"] = 11, ["Trinket"] = 13,
        ["Main Hand"] = 16, ["Off Hand"] = 17
    }

    print(">> DEBUG: Analyzing item link: " .. tostring(itemLink))

    local tooltip = CreateFrame("GameTooltip", "LootTrackerSlotTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)

    for i = 1, tooltip:NumLines() do
        local line = _G["LootTrackerSlotTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text then
            print(">> DEBUG: Tooltip line " .. i .. ": " .. text)
            for keyword, slotID in pairs(slotKeywords) do
                if text:find(keyword) then
                    print(">> DEBUG: Found keyword '" .. keyword .. "' → Slot ID: " .. slotID)
                    return slotID
                end
            end
        end
    end

    print(">> DEBUG: No matching slot keyword found in tooltip for item.")
    return nil
end

-- 📦 Detect Item Type from Tooltip (Simplified)
function GetItemType(itemLink)
    print(">> DEBUG: Resolving item type for link: " .. tostring(itemLink))

    local tooltip = CreateFrame("GameTooltip", "LootTrackerTypeTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)

    for i = 1, tooltip:NumLines() do
        local line = _G["LootTrackerTypeTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text then
            print(">> DEBUG: Tooltip line " .. i .. ": " .. text)

            if text:find("Trinket") then
                print(">> DEBUG: Matched 'Trinket' → INVTYPE_TRINKET")
                return "INVTYPE_TRINKET"
            end
            if text:find("Finger") then
                print(">> DEBUG: Matched 'Finger' → INVTYPE_FINGER")
                return "INVTYPE_FINGER"
            end
            if text:find("Two%-Hand") then
                print(">> DEBUG: Matched 'Two-Hand' → INVTYPE_2HWEAPON")
                return "INVTYPE_2HWEAPON"
            end
            if text:find("Main Hand") then
                print(">> DEBUG: Matched 'Main Hand' → INVTYPE_WEAPONMAINHAND")
                return "INVTYPE_WEAPONMAINHAND"
            end
            if text:find("Off Hand") or text:find("Shield") then
                print(">> DEBUG: Matched 'Off Hand' or 'Shield' → INVTYPE_WEAPONOFFHAND")
                return "INVTYPE_WEAPONOFFHAND"
            end
        end
    end

    print(">> DEBUG: No item type keyword matched in tooltip.")
    return nil
end

-- 🧠 Compare If Player Has Superior Gear
local function HasBetterItem(playerName, itemLink, mode)
    local trackNew = GetUpgradeTrack(itemLink)
    local ilvlNew = GetItemLevel(itemLink)
    local seasonNew = GetItemSeason(itemLink) or CURRENT_SEASON
    local isCrafted = IsCrafted(itemLink)

    print(">> DEBUG: Checking loot for " .. playerName)
    print(">> DEBUG: Loot item → Track=" .. tostring(trackNew) ..
          ", iLvl=" .. tostring(ilvlNew) ..
          ", Season=" .. tostring(seasonNew) ..
          ", Crafted=" .. tostring(isCrafted))

    if not ilvlNew then
        print(">> DEBUG: Missing ilvl for loot item.")
        return false
    end

    local slotsToCheck = ResolveSlots(itemLink)
    print(">> DEBUG: Resolved slots to check: " .. table.concat(slotsToCheck, ", "))

    local allSlotsSuperior = true

    for _, slot in ipairs(slotsToCheck) do
        local equipped = GetInventoryItemLink(playerName, slot)
        if equipped then
            local eqTrack = GetUpgradeTrack(equipped)
            local eqIlvl = GetItemLevel(equipped)
            local eqSeason = GetItemSeason(equipped) or CURRENT_SEASON
            local eqIsCrafted = IsCrafted(equipped)

            print(">> DEBUG: Equipped item in slot " .. slot ..
                  " → Track=" .. tostring(eqTrack) ..
                  ", iLvl=" .. tostring(eqIlvl) ..
                  ", Season=" .. tostring(eqSeason) ..
                  ", Crafted=" .. tostring(eqIsCrafted))

            if eqIlvl then
                local isSuperior = false

                if mode == "ilvl" then
                    isSuperior = eqIlvl >= ilvlNew
                    print(">> DEBUG: Mode='ilvl' → Comparing Equipped iLvl " .. eqIlvl .. " vs Loot iLvl " .. ilvlNew)
                else
                    if eqTrack then
                        if isCrafted then
                            local maxTrackIlvl = TRACK_MAX_ILVL[trackNew]
                            print(">> DEBUG: Crafted comparison → MaxTrackILvl=" .. tostring(maxTrackIlvl))
                            isSuperior = maxTrackIlvl and eqIlvl >= maxTrackIlvl
                        else
                            print(">> DEBUG: Non-crafted comparison")
                            if eqSeason > seasonNew then
                                print(">> DEBUG: Equipped item is from newer season.")
                                isSuperior = true
                            elseif eqSeason < seasonNew then
                                print(">> DEBUG: Equipped item is from older season.")
                                isSuperior = false
                            else
                                isSuperior = (TRACK_ORDER[eqTrack] > TRACK_ORDER[trackNew]) or
                                             (TRACK_ORDER[eqTrack] == TRACK_ORDER[trackNew] and eqIlvl >= ilvlNew)
                                print(">> DEBUG: Mode='track' → Order=" .. tostring(TRACK_ORDER[eqTrack]) ..
                                      " vs " .. tostring(TRACK_ORDER[trackNew]) ..
                                      ", iLvl=" .. tostring(eqIlvl) .. " vs " .. tostring(ilvlNew))
                            end
                        end
                    else
                        print(">> DEBUG: Missing eqTrack for 'track' mode. Assuming loot is better.")
                        isSuperior = false
                    end
                end

                if not isSuperior then
                    print(">> DEBUG: Loot is better or equal in slot " .. slot)
                    allSlotsSuperior = false
                else
                    print(">> DEBUG: Equipped item is superior in slot " .. slot)
                end
            else
                print(">> DEBUG: Missing item level for equipped item in slot " .. slot)
                allSlotsSuperior = false
            end
        else
            print(">> DEBUG: No item equipped in slot " .. slot)
            allSlotsSuperior = false
        end
    end

    print(">> DEBUG: All slots superior = " .. tostring(allSlotsSuperior))
    return allSlotsSuperior
end

-- 📡 Live Raid Roll Evaluation
local function EvaluateModernLootRolls(mode)
    mode = (mode == "ilvl") and "ilvl" or "track"
    print(">> DEBUG: Evaluation mode set to: " .. mode)

    local encounters = C_LootHistory.GetAllEncounterInfos()
    if not encounters then
        print(">> DEBUG: No encounter history found.")
        return
    end

    for _, encounter in ipairs(encounters) do
        print(">> DEBUG: Processing encounter: " .. tostring(encounter.encounterID))
        local drops = C_LootHistory.GetSortedDropsForEncounter(encounter.encounterID)

        if drops then
            for _, drop in ipairs(drops) do
                local item = drop.itemHyperlink
                local winnerInfo = drop.winner
                local rollInfos = drop.rollInfos

                print(">> DEBUG: Found drop: " .. tostring(item))

                if item and winnerInfo and rollInfos then
                    local winnerName = winnerInfo.playerName
                    local valid = {}

                    for _, r in ipairs(rollInfos) do
                        print(">> DEBUG: Roll by " .. r.playerName .. 
                              " → State=" .. tostring(r.state) .. 
                              ", Winner=" .. tostring(r.isWinner))

                        if r.state == Enum.EncounterLootDropRollState.NeedMainSpec then
                            local hasBetter = HasBetterItem(r.playerName, item, mode)
                            print(">> DEBUG: " .. r.playerName .. " HasBetterItem=" .. tostring(hasBetter))
                            table.insert(valid, {
                                name = r.playerName,
                                won = r.isWinner,
                                betterGear = hasBetter
                            })
                        end
                    end

                    print(">>RaidTools " .. winnerName .. " won this item: " .. item)

                    for _, r in ipairs(valid) do
                        if r.betterGear then
                            print(">>RaidTools " .. r.name .. " is a ninja looter.")
                        end
                    end

                    for _, r in ipairs(valid) do
                        if r.betterGear and r.won then
                            for _, other in ipairs(valid) do
                                if not other.won and not other.betterGear then
                                    print(">>RaidTools " .. r.name .. " pass " .. item .. 
                                          " to the next roller who needs it: " .. other.name)
                                    break
                                end
                            end
                        end
                    end
                else
                    print(">> DEBUG: Missing item/winner/rollInfos in drop data.")
                end
            end
        else
            print(">> DEBUG: No drops found for encounter " .. tostring(encounter.encounterID))
        end
    end
end

-- 🔁 Live Raid Event Hook
local frame = CreateFrame("Frame")
frame:RegisterEvent("LOOT_ROLLS_COMPLETE")
frame:SetScript("OnEvent", function(_, event)
    if event == "LOOT_ROLLS_COMPLETE" then
        EvaluateModernLootRolls(_G.RaidToolsDB and _G.RaidToolsDB.rollMode or "track")
    end
end)

-- 🌐 Export to Global Namespace
_G.LootTracker = LootTracker