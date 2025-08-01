print(">> RaidTools: LootTracker loaded")
local LootTracker = {}

-- 📊 Track Rankings and Max Item Levels
local TRACK_ORDER = {
    ["Explorer"] = 1, ["Adventurer"] = 2,
    ["Veteran"] = 3, ["Champion"] = 4,
    ["Hero"] = 5, ["Myth"] = 6
}

local TRACK_MAX_ILVL = {
    ["Explorer"] = 619, ["Adventurer"] = 632,
    ["Veteran"] = 645, ["Champion"] = 658,
    ["Hero"] = 671, ["Myth"] = 684
}

local SLOT_NAME_MAPPING = {
    ["Head"] = { "HEADSLOT" },
    ["Neck"] = { "NECKSLOT" },
    ["Shoulder"] = { "SHOULDERSLOT" },
    ["Shirt"] = { "SHIRTSLOT" },
    ["Chest"] = { "CHESTSLOT" },
    ["Waist"] = { "WAISTSLOT" },
    ["Legs"] = { "LEGSSLOT" },
    ["Feet"] = { "FEETSLOT" },
    ["Wrist"] = { "WRISTSLOT" },
    ["Hands"] = { "HANDSSLOT" },
    ["Back"] = { "BACKSLOT" },
    ["Finger"] = { "FINGER0SLOT", "FINGER1SLOT" },
    ["Trinket"] = { "TRINKET0SLOT", "TRINKET1SLOT" },
    ["One-%Hand"] = { "MAINHANDSLOT" },
    ["Two-%Hand"] = { "MAINHANDSLOT" },
    ["Held In Off%-Hand"] = { "SECONDARYHANDSLOT" },
    ["Ranged"] = { "RANGEDSLOT" },
    ["Tabard"] = { "TABARDSLOT" }
}

local function GetInventorySlotsFromParsed(parsedSlotName)
    local tokens = SLOT_NAME_MAPPING[parsedSlotName]
    if not tokens then
        RaidToolsUtils.PrintDebug("No mapping for parsed slot name: " .. tostring(parsedSlotName))
        return {}
    end

    local slotIds = {}
    for _, token in ipairs(tokens) do
        local slotId = GetInventorySlotInfo(token)
        if slotId then
            table.insert(slotIds, slotId)
        end
    end
    return slotIds
end

-- New System
local function ParseTooltipLines(tooltip)
    local parsed = {
        itemLevel = nil,
        upgradeTrack = nil,
        slot = nil,
        isCrafted = false,
        isLegacySeasonGear = false
    }

    local slotMatchers = {
        "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands",
        "Waist", "Legs", "Feet", "Finger", "Trinket",
        "One-%Hand", "Two-%Hand", "Held In Off%-Hand"
    }

    for i = i, tooltip:NumLines() do
        local line = _G["LootTrackerTooltipTextLeft" .. i]:GetText()
        if line then
            -- Item Level
            local ilvl = line:match("Item Level (%d+)")
            if ilvl then parsed.itemLevel = tonumber(ilvl) end

            -- Upgrade Track
            local track = line:match("Upgrade Level: (%a+) (%d+)/%d+")
            if track then parsed.upgradeTrack = track end

            -- Slot
            for _, matcher in ipairs(slotMatchers) do
                if line:find(matcher) then
                    parsed.slot = matcher:gsub("%%%-", "-")
                    break
                end
            end

            -- Crafted Check
            if line:lower():find("crafted") then parsed.isCrafted = true end

            -- Season Check
            if line:lower():find("season") then parsed.isLegacySeasonGear = true end
        end
    end

    return parsed
end

function ScanTooltip(tooltip, itemLink)
    local parsed = ParseTooltipLines(tooltip)
    parsed.itemLink = itemLink
    return parsed
end

function ScanItem(itemLink)
    local tooltip = CreateFrame("GameTooltip", "LootTrackerTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)

    return ScanTooltip(tooltip, itemLink)
end

-- Compares loot against a list of equipped itemLinks
local function IsLootBetterThanEquipped(parsedLoot, equippedLinks)
    local mode = _G.RaidToolsDB and _G.RaidToolsDB.rollMode or "track"

    for _, eqLink in ipairs(equippedLinks) do
        local eq = ScanItem(eqLink)

        if eq.itemLevel then
            if mode == "ilvl" then
                if parsedLoot.itemLevel > eq.itemLevel then return true end
            else
                if parsedLoot.isCrafted then
                    local maxTrackIlvl = TRACK_MAX_ILVL[parsedLoot.upgradeTrack]
                    if maxTrackIlvl then
                        if eq.itemLevel >= maxTrackIlvl then
                            return false
                        elseif parsedLoot.itemLevel > eq.itemLevel then
                            return true
                        end
                    end
                else
                    if eq.isLegacySeasonGear and not parsedLoot.isLegacySeasonGear then
                        return true
                    elseif not eq.isLegacySeasonGear and parsedLoot.isLegacySeasonGear then
                        return false
                    end

                    local eqOrder = TRACK_ORDER[eq.upgradeTrack] or 0
                    local lootOrder = TRACK_ORDER[parsedLoot.upgradeTrack] or 0

                    if lootOrder > eqOrder or
                       (lootOrder == eqOrder and parsedLoot.itemLevel > eq.itemLevel) then
                        return true
                    end
                end
            end
        end
    end

    -- If loot is OFF-HAND, and equipped is a Two-Hander, treat as future potential
    if parsedLoot.slot == "OFFHAND" and parsedLoot.subClass:match("Held In Off%-Hand") then
        for _, eqLink in ipairs(equippedLinks) do
            local eq = ScanItem(eqLink)
            if eq and eq.subClass and eq.subClass:match("Two%-Hand") then
                local lootOrder = TRACK_ORDER[parsedLoot.upgradeTrack] or 0
                local eqOrder = TRACK_ORDER[eq.upgradeTrack] or 0
                if lootOrder > eqOrder then
                    RaidToolsUtils.PrintDebug("Future Combo Flag: Off-hand is from higher track than equipped 2H — consider pairing with 1H.")
                    return true
                end
            end
        end
    end

    -- If loot is ONE-HAND, and equipped is a Two-Hander, treat as future potential
    if parsedLoot.slot == "MAINHAND" and parsedLoot.subClass:match("One%-Hand") then
        for _, eqLink in ipairs(equippedLinks) do
            local eq = ScanItem(eqLink)
            if eq and eq.subClass and eq.subClass:match("Two%-Hand") then
                local lootOrder = TRACK_ORDER[parsedLoot.upgradeTrack] or 0
                local eqOrder = TRACK_ORDER[eq.upgradeTrack] or 0
                if lootOrder > eqOrder then
                    RaidToolsUtils.PrintDebug("Future Combo Flag: 1H weapon from higher track than equipped 2H — off-hand pairing possible.")
                    return true
                end
            end
        end
    end

    -- If loot is TWO-HAND, check against both 1H + OH — must be better than at least one
    if parsedLoot.subClass and parsedLoot.subClass:match("Two%-Hand") then
        for _, eqLink in ipairs(equippedLinks) do
            local eq = ScanItem(eqLink)
            if eq and eq.itemLevel and (eq.subClass:match("One%-Hand") or eq.subClass:match("Held In Off%-Hand")) then
                if parsedLoot.itemLevel > eq.itemLevel then
                    RaidToolsUtils.PrintDebug("Weapon Upgrade Check: 2H is stronger than one of the current 1H/OH combo.")
                    return true
                end
            end
        end
    end

    return false
end

-- Evaluates if the loot item is an upgrade for player
local function HasBetterItem(playerName, itemLink)
    local parsedLoot = ScanItem(itemLink)
    if not parsedLoot or not parsedLoot.itemLevel or not parsedLoot.slot then
        RaidToolsUtils.PrintDebug("Invalid loot item.")
        return false
    end

    local slotIds = GetInventorySlotsFromParsed(parsedLoot.slot)
    if #slotIds == 0 then
        RaidToolsUtils.PrintDebug("Could not resolve slot(s) for " .. parsedLoot.slot)
        return false
    end

    local equippedLinks = {}
    for _, slotId in ipairs(slotIds) do
        local eqLink = GetInventoryItemLink(playerName, slotId)
        if eqLink then table.insert(equippedLinks, eqLink) end
    end

    if #equippedLinks == 0 then
        RaidToolsUtils.PrintDebug("No equipped items found in slot(s) " .. parsedLoot.slot)
        return false
    end

    local isUpgrade = IsLootBetterThanEquipped(parsedLoot, equippedLinks)
    RaidToolsUtils.PrintDebug("Loot upgrade status for " .. parsedLoot.slot .. " → " .. tostring(isUpgrade))
    return isUpgrade
end

-- 📡 Live Raid Roll Evaluation
local function EvaluateModernLootRolls()

    local encounters = C_LootHistory.GetAllEncounterInfos()
    if not encounters then
        RaidToolsUtils.PrintDebug("No encounter history found.")
        return
    end

    for _, encounter in ipairs(encounters) do
        RaidToolsUtils.PrintDebug("Processing encounter: " .. tostring(encounter.encounterID))
        local drops = C_LootHistory.GetSortedDropsForEncounter(encounter.encounterID)

        if drops then
            for _, drop in ipairs(drops) do
                local item = drop.itemHyperlink
                local winnerInfo = drop.winner
                local rollInfos = drop.rollInfos

                RaidToolsUtils.PrintDebug("Found drop: " .. tostring(item))

                if item and winnerInfo and rollInfos then
                    local winnerName = winnerInfo.playerName
                    local valid = {}

                    for _, r in ipairs(rollInfos) do
                        RaidToolsUtils.PrintDebug(r.playerName .. " rolled " .. r.state .. " with " .. tostring(r.roll) .. " for " .. item .. ". Won = " .. r.isWinner)

                        if r.state == Enum.EncounterLootDropRollState.NeedMainSpec then
                            local hasBetter = HasBetterItem(r.playerName, item)
                            RaidToolsUtils.PrintDebug(r.playerName .. " HasBetterItem=" .. tostring(hasBetter))
                            table.insert(valid, {
                                name = r.playerName,
                                won = r.isWinner,
                                betterGear = hasBetter,
                                rollValue = r.roll
                            })
                        end

                        table.sort(valid, function(a, b)
                            return (a.rollValue or 0) > (b.rollValue or 0)
                        end)
                    end

                    RaidToolsUtils.PrintDebug(winnerName .. " won this item: " .. item)

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
                    RaidToolsUtils.PrintDebug("Mssing item/winner/rollInfos in drop data.")
                end
            end
        else
            RaidToolsUtils.PrintDebug("No drops found for encounter " .. tostring(encounter.encounterID))
        end
    end
end

SLASH_PARSELOOT1 = "/parseloot"
SlashCmdList["PARSELOOT"] = function(msg)
    local itemLink = msg:match("|c.-|r")
    if not itemLink then
        print("Usage: /parseloot [itemLink] ← shift-click an item")
        return
    end

    local parsed = ScanItem(itemLink)
    if not parsed then
        print(">> DEBUG: Could not parse item.")
        return
    end

    -- Print parsed loot
    print(">> Parsed Loot: " .. itemLink)
    print("  • Item Level: " .. parsed.itemLevel)
    print("  • Upgrade Track: " .. parsed.upgradeTrack)
    print("  • Slot: " .. parsed.slot)
    print("  • Crafted: " .. tostring(parsed.isCrafted))
    print("  • Legacy Season Gear: " .. tostring(parsed.isLegacySeasonGear))

    -- Expanded slot mapping for more accurate comparison
    local slots = {
        ["HEAD"] = 1,
        ["NECK"] = 2,
        ["SHOULDER"] = 3,
        ["CHEST"] = 5,
        ["WAIST"] = 6,
        ["LEGS"] = 7,
        ["FEET"] = 8,
        ["WRIST"] = 9,
        ["HANDS"] = 10,
        ["FINGER"] = {11, 12},
        ["TRINKET"] = {13, 14},
        ["BACK"] = 15,
        ["MAINHAND"] = 16,
        ["OFFHAND"] = 17,
        ["RANGED"] = 18
    }

    local equipSlot = slots[parsed.slot]
    if not equipSlot then
        print(">> DEBUG: Unknown equip slot for comparison [" .. tostring(parsed.slot) .. "]")
        return
    end

    local equippedItems = type(equipSlot) == "table" and equipSlot or {equipSlot}
    for _, slotID in ipairs(equippedItems) do
        local equippedLink = GetInventoryItemLink("player", slotID)
        if equippedLink then
            local equippedParsed = ScanItem(equippedLink)
            print(">> Equipped Item (Slot " .. slotID .. "): " .. equippedLink)
            print("  • Item Level: " .. equippedParsed.itemLevel)
            print("  • Upgrade Track: " .. equippedParsed.upgradeTrack)
            print("  • Crafted: " .. tostring(equippedParsed.isCrafted))
            print("  • Legacy Season Gear: " .. tostring(equippedParsed.isLegacySeasonGear))
        else
            print(">> Equipped Slot " .. slotID .. ": (empty)")
        end
    end
end

-- 🔁 Live Raid Event Hook
local frame = CreateFrame("Frame")
frame:RegisterEvent("LOOT_ROLLS_COMPLETE")
frame:SetScript("OnEvent", function(_, event)
    if event == "LOOT_ROLLS_COMPLETE" then
        EvaluateModernLootRolls()
    end
end)

-- 🌐 Export to Global Namespace
_G.LootTracker = LootTracker