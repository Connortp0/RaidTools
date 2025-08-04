print(">> RaidTools: LootTracker loaded")
local LootTracker = {}

-- 📊 Track Rankings and Max Item Levels
local TRACK_ORDER = {
    ["explorer"] = 1, ["adventurer"] = 2,
    ["veteran"] = 3, ["champion"] = 4,
    ["hero"] = 5, ["myth"] = 6
}

local TRACK_MAX_ILVL = {
    ["explorer"] = 619, ["adventurer"] = 632,
    ["veteran"] = 645, ["champion"] = 658,
    ["hero"] = 671, ["myth"] = 684
}

local SLOT_NAME_MAPPING = {
    ["head"] = { "HEADSLOT" },
    ["neck"] = { "NECKSLOT" },
    ["shoulder"] = { "SHOULDERSLOT" },
    ["shirt"] = { "SHIRTSLOT" },
    ["chest"] = { "CHESTSLOT" },
    ["waist"] = { "WAISTSLOT" },
    ["legs"] = { "LEGSSLOT" },
    ["feet"] = { "FEETSLOT" },
    ["wrist"] = { "WRISTSLOT" },
    ["hands"] = { "HANDSSLOT" },
    ["back"] = { "BACKSLOT" },
    ["finger"] = { "FINGER0SLOT", "FINGER1SLOT" },
    ["trinket"] = { "TRINKET0SLOT", "TRINKET1SLOT" },
    ["one-hand"] = { "MAINHANDSLOT" },
    ["two-hand"] = { "MAINHANDSLOT" },
    ["main hand"] = { "MAINHANDSLOT" },
    ["off hand"] = { "SECONDARYHANDSLOT" },
    ["held in off-hand"] = { "SECONDARYHANDSLOT" },
    ["ranged"] = { "RANGEDSLOT" },
    ["tabard"] = { "TABARDSLOT" }
}

function GetTrackOrder(track)
    return TRACK_ORDER[(track or ""):lower()] or 0
end

local function GetInventorySlotsFromParsed(parsedSlotName)
    local tokens = SLOT_NAME_MAPPING[parsedSlotName]
    if not tokens then
        print("No mapping for parsed slot name: " .. tostring(parsedSlotName))
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

    -- Patterns expected in tooltip text
    local slotMatchers = {
        "head", "neck", "shoulder", "back", "chest", "wrist", "hands",
        "waist", "legs", "feet", "finger", "trinket",
        "one%-hand", "two%-hand", "held in off%-hand", "ranged", "one-hand", "two-hand", "held in off-hand"
    }

    -- Scan tooltip regions for text
    local regions = { tooltip:GetRegions() }
    if regions then
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                local line = region:GetText()
                if line then
                    line = line:lower() -- Normalize to lowercase for easier matching
                    print("Parsing line: " .. line)
                    -- 🎯 Parse item level
                    local ilvl = line:match("item level (%d+)")
                    if ilvl then parsed.itemLevel = tonumber(ilvl) end

                    -- 🎯 Parse upgrade track
                    local track = line:match("upgrade level: (%a+) (%d+)/%d+")
                    if track then parsed.upgradeTrack = track end

                    -- 🎯 Match slot name
                    for _, matcher in ipairs(slotMatchers) do
                        if line:find(matcher) then
                            parsed.slot = matcher:gsub("%%%-", "-") -- Normalize pattern to raw string
                            break
                        end
                    end

                    -- 🧵 Crafted gear flag
                    if line:find("crafted") then parsed.isCrafted = true end

                    -- 🏷️ Legacy season detection
                    if line:find("season") then parsed.isLegacySeasonGear = true end
                end
            end
        end
    end
    return parsed
end

function ScanTooltip(tooltip, itemLink)
    local parsed = ParseTooltipLines(tooltip)
    parsed.itemLink = itemLink

    -- Add subclass info from API
    local _, _, _, _, _, _, subClass = C_Item.GetItemInfo(itemLink)
    parsed.subClass = subClass

    return parsed
end

local lootScanTooltip = CreateFrame("GameTooltip", "LootTrackerTooltip", UIParent, "GameTooltipTemplate")
lootScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

function ScanItem(itemLink)
    lootScanTooltip:ClearLines()
    lootScanTooltip:SetHyperlink(itemLink)
    lootScanTooltip:Show()

    return ScanTooltip(lootScanTooltip, itemLink)
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

    -- Future combo logic for off-hand and 1H weapons
    -- 🛡️ Off-hand vs equipped 2H
    if parsedLoot.slot == "OFFHAND" and parsedLoot.subClass:match("Held In Off%-Hand") then
        for _, eqLink in ipairs(equippedLinks) do
            local eq = ScanItem(eqLink)
            if eq and eq.subClass and eq.subClass:match("Two%-Hand") then
                local isUpgrade = (mode == "ilvl") and (parsedLoot.itemLevel > eq.itemLevel) or
                                (GetTrackOrder(parsedLoot.upgradeTrack) > GetTrackOrder(eq.upgradeTrack))
                if isUpgrade then
                    print("Future Combo Flag: Off-hand beats current 2H — consider pairing with 1H.")
                    return true
                end
            end
        end
    end

    -- 🛡️ Mainhand 1H vs equipped 2H
    if parsedLoot.slot == "MAINHAND" and parsedLoot.subClass:match("One%-Hand") then
        for _, eqLink in ipairs(equippedLinks) do
            local eq = ScanItem(eqLink)
            if eq and eq.subClass and eq.subClass:match("Two%-Hand") then
                local isUpgrade = (mode == "ilvl") and (parsedLoot.itemLevel > eq.itemLevel) or
                                (GetTrackOrder(parsedLoot.upgradeTrack) > GetTrackOrder(eq.upgradeTrack))
                if isUpgrade then
                    print("Future Combo Flag: 1H weapon may support future off-hand pairing.")
                    return true
                end
            end
        end
    end

    -- ⚖️ 2H vs 1H+OH — compare against weakest equipped item
    if parsedLoot.subClass and parsedLoot.subClass:match("Two%-Hand") then
        local lowestEquipped = nil
        for _, eqLink in ipairs(equippedLinks) do
            local eq = ScanItem(eqLink)
            if eq and (eq.subClass:match("One%-Hand") or eq.subClass:match("Held In Off%-Hand")) then
                local value = (mode == "ilvl") and eq.itemLevel or GetTrackOrder(eq.upgradeTrack)
                if not lowestEquipped or value < lowestEquipped then
                    lowestEquipped = value
                end
            end
        end
        local lootValue = (mode == "ilvl") and parsedLoot.itemLevel or GetTrackOrder(parsedLoot.upgradeTrack)
        if lowestEquipped and lootValue > lowestEquipped then
            print("Weapon Upgrade Check: 2H beats weakest item in 1H/OH combo.")
            return true
        end
    end

    -- 💍 Paired slots (ring/trinket)
    if parsedLoot.slot == "FINGER" or parsedLoot.slot == "TRINKET" then
        local lowestEquipped = nil
        for _, eqLink in ipairs(equippedLinks) do
            local eq = ScanItem(eqLink)
            if eq and eq.slot == parsedLoot.slot then
                local value = (mode == "ilvl") and eq.itemLevel or GetTrackOrder(eq.upgradeTrack)
                if not lowestEquipped or value < lowestEquipped then
                    lowestEquipped = value
                end
            end
        end
        local lootValue = (mode == "ilvl") and parsedLoot.itemLevel or GetTrackOrder(parsedLoot.upgradeTrack)
        if lowestEquipped and lootValue > lowestEquipped then
            print("Upgrade Check: Loot beats weakest equipped " .. parsedLoot.slot .. ".")
            return true
        end
    end

    return false
end

-- Evaluates if the loot item is an upgrade for player
local function HasBetterItem(playerName, itemLink)
    print("Scanning item for " .. playerName .. ": " .. itemLink)
    local parsedLoot = ScanItem(itemLink)
    if not parsedLoot then
        print("ScanItem returned nil")
        return false
    end
    for k, v in pairs(parsedLoot) do
        print("  • " .. k .. ": " .. tostring(v))
    end

    if not parsedLoot.slot then
        print("Item has no slot field: " .. itemLink)
        return false
    end

    local slotIds = GetInventorySlotsFromParsed(parsedLoot.slot)
    if #slotIds == 0 then
        print("Could not resolve slot(s) for " .. parsedLoot.slot)
        return false
    end

    local equippedLinks = {}

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unitToken = "raid" .. i
            local name, _ = UnitName(unitToken)
            if name and name == playerName then
                for _, slotId in ipairs(slotIds) do
                    local eqLink = GetInventoryItemLink(unitToken, slotId)
                    if eqLink then
                        table.insert(equippedLinks, eqLink)
                    end
                end
                break
            end
        end
    end

    if #equippedLinks == 0 then
        print("No equipped items found in slot(s) " .. parsedLoot.slot)
        return false
    end

    local isUpgrade = IsLootBetterThanEquipped(parsedLoot, equippedLinks)
    print("Loot upgrade status for " .. parsedLoot.slot .. " → " .. tostring(isUpgrade))
    return isUpgrade
end

-- 📡 Live Raid Roll Evaluation
local function EvaluateModernLootRolls()

    local processedEncounters = {}

    local encounters = C_LootHistory.GetAllEncounterInfos()
    if not encounters then
        print("No encounter history found.")
        return
    end

    for _, encounter in ipairs(encounters) do
        if not processedEncounters[encounter.encounterID] then
            processedEncounters[encounter.encounterID] = true
            print("Processing encounter: " .. tostring(encounter.encounterID))
            local drops = C_LootHistory.GetSortedDropsForEncounter(encounter.encounterID)

            if drops then
                for _, drop in ipairs(drops) do
                    local item = drop.itemHyperlink
                    local winnerInfo = drop.winner
                    local rollInfos = drop.rollInfos

                    print("Found drop: " .. tostring(item))

                    if item and winnerInfo and rollInfos then
                        local winnerName = winnerInfo.playerName
                        local valid = {}

                        for _, r in ipairs(rollInfos) do

                            if r.state == Enum.EncounterLootDropRollState.NeedMainSpec then
                                C_Timer.After(0.3, function()
                                    print(r.playerName .. " rolled " .. tostring(r.state) .. " with " .. tostring(r.roll) .. " for " .. item .. ". Won = " .. tostring(r.isWinner))
                                    local hasBetter = HasBetterItem(r.playerName, item)
                                    print(r.playerName .. " HasBetterItem=" .. tostring(hasBetter))
                                    table.insert(valid, {
                                        name = r.playerName,
                                        won = r.isWinner,
                                        betterGear = hasBetter,
                                        rollValue = r.roll
                                    })
                                end)
                            end

                            table.sort(valid, function(a, b)
                                return (a.rollValue or 0) > (b.rollValue or 0)
                            end)
                        end

                        print(winnerName .. " won this item: " .. item)

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
                        print("Mssing item/winner/rollInfos in drop data.")
                    end
                end
            else
                print("No drops found for encounter " .. tostring(encounter.encounterID))
            end
        end
    end
end

SLASH_PARSEGEAR1 = "/parsegear"
SlashCmdList["PARSEGEAR"] = function(msg)
    local slotMatchers = {
        "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands",
        "Waist", "Legs", "Feet", "Finger", "Trinket",
        "One-Hand", "Two-Hand", "Held In Off-Hand"
    }

    -- Normalize input
    local inputSlot = msg and msg:gsub("^%s*", ""):gsub("%s*$", "")
    if not inputSlot or inputSlot == "" then
        print("Usage: /parsegear [SlotName]")
        print("Available slots:")
        for _, slot in ipairs(slotMatchers) do
            print("  • " .. slot)
        end
        return
    end

    -- Match against known slot names
    local normalized = inputSlot:gsub("%%%-", "-")
    local matchedSlot = nil
    for _, slot in ipairs(slotMatchers) do
        if slot:lower() == normalized:lower() then
            matchedSlot = slot
            break
        end
    end

    if not matchedSlot then
        print("Invalid slot: " .. inputSlot)
        print("Try one of the following:")
        for _, slot in ipairs(slotMatchers) do
            print("  • " .. slot)
        end
        return
    end

    -- Map to slot token(s)
    local SLOT_NAME_MAPPING = {
        ["Head"] = { "HEADSLOT" },
        ["Neck"] = { "NECKSLOT" },
        ["Shoulder"] = { "SHOULDERSLOT" },
        ["Back"] = { "BACKSLOT" },
        ["Chest"] = { "CHESTSLOT" },
        ["Wrist"] = { "WRISTSLOT" },
        ["Hands"] = { "HANDSSLOT" },
        ["Waist"] = { "WAISTSLOT" },
        ["Legs"] = { "LEGSSLOT" },
        ["Feet"] = { "FEETSLOT" },
        ["Finger"] = { "FINGER0SLOT", "FINGER1SLOT" },
        ["Trinket"] = { "TRINKET0SLOT", "TRINKET1SLOT" },
        ["One-Hand"] = { "MAINHANDSLOT" },
        ["Two-Hand"] = { "MAINHANDSLOT" },
        ["Held In Off-Hand"] = { "SECONDARYHANDSLOT" }
    }

    local tokens = SLOT_NAME_MAPPING[matchedSlot]
    if not tokens then
        print("No slot mapping for: " .. matchedSlot)
        return
    end

    local slotIds = {}
    for _, token in ipairs(tokens) do
        local slotId = GetInventorySlotInfo(token)
        if slotId then table.insert(slotIds, slotId) end
    end

    if #slotIds == 0 then
        print("No equipped slot IDs found for: " .. matchedSlot)
        return
    end

    -- Scan and print equipped items in matched slot(s)
    for _, slotId in ipairs(slotIds) do
        local equippedLink = GetInventoryItemLink("player", slotId)
        if equippedLink then
            local equippedParsed = ScanItem(equippedLink)
            print(">> Equipped (" .. matchedSlot .. " Slot " .. slotId .. "): " .. equippedLink)
            print("  • Item Level: " .. tostring(equippedParsed.itemLevel or "N/A"))
            if equippedParsed.isCrafted == false then print("  • Upgrade Track: " .. tostring(equippedParsed.upgradeTrack or "N/A")) end
            print("  • Crafted: " .. tostring(equippedParsed.isCrafted))
            if equippedParsed.isCrafted == false then print("  • Legacy Season Gear: " .. tostring(equippedParsed.isLegacySeasonGear)) end
        else
            print(">> Equipped Slot " .. slotId .. ": (empty)")
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