print(">> RaidTools: LootTrackerV2 loaded")
-- Variables
local LootTrackerV2 = {}

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
    Head = { "HEADSLOT" },
    Neck = { "NECKSLOT" },
    Shoulder = { "SHOULDERSLOT" },
    Back = { "BACKSLOT" },
    Chest = { "CHESTSLOT" },
    Wrist = { "WRISTSLOT" },
    Hands = { "HANDSSLOT" },
    Waist = { "WAISTSLOT" },
    Legs = { "LEGSSLOT" },
    Feet = { "FEETSLOT" },
    Finger = { "FINGER0SLOT", "FINGER1SLOT" },
    Trinket = { "TRINKET0SLOT", "TRINKET1SLOT" },
    ["One-Hand"] = { "MAINHANDSLOT", "SECONDARYHANDSLOT" },
    Ranged = { "RANGEDSLOT" },
    ["Held In Off-Hand"] = { "SECONDARYHANDSLOT" },
    ["Off-Hand"] = { "SECONDARYHANDSLOT" },
    ["Two-Hand"] = { "MAINHANDSLOT" }
}

-- Helper Functions
local function GetTrackOrder(track)
    return TRACK_ORDER[track:lower()] or 0
end

local function GetTrackMaxIlvl(track)
    return TRACK_MAX_ILVL[track:lower()] or 0
end

local function GetInventorySlotsFromParsed(parsedSlotName)
    local tokens = SLOT_NAME_MAPPING[parsedSlotName]
    if not tokens then
        print("No slot mapping for: " .. tostring(parsedSlotName))
        return {}
    end

    local slotIds = {}
    for _, token in ipairs(tokens) do
        local slotId = GetInventorySlotInfo(token)
        if slotId then
            table.insert(slotIds, slotId)
        else
            print("Unable to resolve slot token: " .. token)
        end
    end
    return slotIds
end

-- Tooltip Parsing Functions
local function ParseTooltipLines(tooltip)
    local parsed = {
        itemLevel = nil,
        itemUpgradeTrack = nil,
        itemSlot = nil,
        mainStats = {
            strength = nil,
            agility = nil,
            intellect = nil
        },
        isLegacySeasonGear = nil,
        isCraftedGear = nil,
        isPvPGear = nil
    }

    local slotMatchers = {
        "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands",
        "Waist", "Legs", "Feet", "Finger", "Trinket", "One-Hand",
        "Ranged", "Held In Off-Hand", "Off-Hand", "Two-Hand" 
    }

    local regions = { tooltip:GetRegions() }
    if regions then
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                local line = region:GetText()
                if line then
                    print("Parsing line: " .. line)

                    local ilvl = line:match("Item Level (%d+)")
                    if ilvl then parsed.itemLevel = tonumber(ilvl) end

                    local track = line:match("Upgrade Level: (%a+) (%d+)/%d+")
                    if track then parsed.itemUpgradeTrack = track end

                    for _, matcher in ipairs(slotMatchers) do
                        if line:find(matcher, 1, true) then  -- 'true' enables plain-text matching (no pattern parsing)
                            print("Matched slot:", matcher)
                            parsed.itemSlot = matcher
                            break
                        end
                    end

                    local statKeywords = { "Strength", "Agility", "Intellect" }
                    for _, stat in ipairs(statKeywords) do
                        if line:find(stat) then
                            parsed.mainStats[stat:lower()] = true
                        end
                    end

                    if line:find("Crafted") then parsed.isCraftedGear = true end

                    if line:find("Season") then parsed.isLegacySeasonGear = true end

                    if line:find("Arenas") or line:find("Battlegrounds") then parsed.isPvPGear = true end
                end
            end
        end
    end
    return parsed
end

local function ScanTooltip(tooltip, itemLink)
    local parsed = ParseTooltipLines(tooltip)
    parsed.itemLink = itemLink

    return parsed
end

local lootScanTooltip = CreateFrame("GameTooltip", "LootScanTooltip", UIParent, "GameTooltipTemplate")
lootScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function ScanItem(itemLink)
    lootScanTooltip:ClearLines()
    lootScanTooltip:SetHyperlink(itemLink)

    return ScanTooltip(lootScanTooltip, itemLink)
end

local function IsEquippedItemBetter(equippedLinks, lootLink)
    if not equippedLinks or #equippedLinks == 0 or not lootLink then return false end

    local mode = _G.RaidToolsDB and _G.RaidToolsDB.rollMode or "track"

    local lootParsed = ScanItem(lootLink)
    if not lootParsed then return false end

    -- Equipped PvP or Legacy Season gear: loot is always better
    for _, eqLink in ipairs(equippedLinks) do
        local eq = ScanItem(eqLink)
        if eq and (eq.isPvPGear or eq.isLegacySeasonGear) then
            return false
        end
    end

    -- Weapon synergy checks
    if lootParsed.slot == "OFFHAND" then
        for _, eqLink in ipairs(equippedLinks) do
            local eq = ScanItem(eqLink)
            if eq and eq.subClass and eq.subClass:match("Two%-Hand") then
                local isUpgrade = (mode == "ilvl" and lootParsed.itemLevel > eq.itemLevel) or
                                  (mode == "track" and GetTrackOrder(lootParsed.upgradeTrack) > GetTrackOrder(eq.upgradeTrack))
                if isUpgrade then
                    print("Future Combo Flag: Off-hand beats current 2H — consider pairing with 1H.")
                    return true
                end
            end
        end
    elseif lootParsed.slot == "MAINHAND" then
        for _, eqLink in ipairs(equippedLinks) do
            local eq = ScanItem(eqLink)
            if eq and eq.subClass and eq.subClass:match("Two%-Hand") then
                local isUpgrade = (mode == "ilvl" and lootParsed.itemLevel > eq.itemLevel) or
                                  (mode == "track" and GetTrackOrder(lootParsed.upgradeTrack) > GetTrackOrder(eq.upgradeTrack))
                if isUpgrade then
                    print("Future Combo Flag: 1H weapon may support future off-hand pairing.")
                    return true
                end
            end
        end
    elseif lootParsed.slot == "MAINHAND" then
        local lowestEquippedValue = nil
        for _, eqLink in ipairs(equippedLinks) do
            local eq = ScanItem(eqLink)
            if eq then
                local value = (mode == "ilvl") and eq.itemLevel or GetTrackOrder(eq.upgradeTrack)
                if not lowestEquippedValue or value < lowestEquippedValue then
                    lowestEquippedValue = value
                end
            end
        end
        local lootValue = (mode == "ilvl") and lootParsed.itemLevel or GetTrackOrder(lootParsed.upgradeTrack)
        if lowestEquippedValue and lootValue > lowestEquippedValue then
            print("Weapon Upgrade Check: 2H beats weakest item in 1H/OH combo.")
            return true
        end
    end

    -- Standard comparison across all equipped items in matching slots
    for _, eqLink in ipairs(equippedLinks) do
        local eq = ScanItem(eqLink)
        if eq then
            if mode == "ilvl" then
                if lootParsed.itemLevel > eq.itemLevel then
                    return true
                end
            elseif mode == "track" then
                local lootTrackMax = GetTrackMaxIlvl(lootParsed.upgradeTrack)
                if eq.isCraftedGear then
                    if eq.itemLevel < lootTrackMax then
                        return true
                    end
                else
                    if GetTrackOrder(eq.upgradeTrack) < GetTrackOrder(lootParsed.upgradeTrack) then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function HasBetterItem(playerName, itemLink)
    local unitID = RaidToolsUtils.FindRaidUnit(playerName)
    if not unitID then
        print("Could not find raid unit for player:", playerName)
        return false
    end

    local parsed = ScanItem(itemLink)
    if not parsed or not parsed.itemSlot then
        print("Unable to parse item slot from:", itemLink)
        return false
    end

    local equipSlots = GetInventorySlotsFromParsed(parsed.itemSlot)
    if #equipSlots == 0 then
        print("No valid inventory slots for:", parsed.itemSlot)
        return false
    end

    local allBetter = true -- Start from false-safe assumption

    for _, slotID in ipairs(equipSlots) do
        local equippedLink = GetInventoryItemLink(unitID, slotID)

        if not IsEquippedItemBetter(equippedLink, itemLink) then
            allBetter = false
            break
        end
    end

    return allBetter
end

-- Loot Rolls
local function EvaluateLootRolls()
    local processedEncounters = {}
    local encounters = C_LootHistory.GetAllEncounterInfos()
    if not encounters then
        print("No encounter history found.")
        return
    end
    
    for _, encounter in ipairs(encounters) do
        if not processedEncounters[encounter.encounterID] then
            processedEncounters[encounter.encounterID] = true
            print("Processing encounter: " .. encounter.encounterName .. " (ID: " .. encounter.encounterID .. ")")
            local drops = C_LootHistory.GetSortedDropsForEncounter(encounter.encounterID)
            if drops then
                for _, drop in ipairs(drops) do
                    local item = drop.itemHyperlink
                    local winnerInfo = drop.winner
                    local rollInfos = drop.rollInfos

                    print("Item: " .. item)

                    if item and winnerInfo and rollInfos then
                        local winnerName = winnerInfo.playerName
                        local valid = {}

                        for _, r in ipairs(rollInfos) do
                            if r.state == Enum.EncounterLootDropRollState.NeedMainSpec then
                                print(r.playerName .. " rolled (" .. r.roll .. ") Need on " .. item)
                                -- Check if they already have a better item.
                                local hasBetterGear = HasBetterItem(r.playerName, item)
                                table.insert(valid, {
                                    name = r.playerName,
                                    won = r.isWinner,
                                    roll = r.roll,
                                    hasBetterGear = hasBetterGear
                                })
                            end
                        end

                        table.sort(valid, function(a, b)
                            return (a.roll or 0) > (b.roll or 0)
                        end)

                        print (winnerName .. " won the item: " .. item)

                        for _, r in ipairs(valid) do
                            if r.hasBetterGear == true and r.won == false then
                                print(r.name .. " is greedy")
                            elseif r.hasBetterGear == false and r.won == true then
                                for _, other in ipairs(valid) do
                                    if other.won == false and other.hasBetterGear == false then
                                        print(r.name .. " pass " .. item .. " to the next roller who needs it " .. other.name)
                                        break
                                    end
                                end
                            end
                        end
                    else
                        print("Missing item/winner/rollInfos in drop data.")
                    end
                end
            else
                print("No drops found for encounter " .. encounter.encounterName .. " (ID: " .. encounter.encounterID .. ")")
            end
        end
    end         
end

-- TESTING
SLASH_LOOTTRACKERV2TEST1 = "/ltv2test"

SlashCmdList["LOOTTRACKERV2TEST"] = function(arg)
    if not arg or arg == "" then
        print("Usage: /ltv2test <slotName>")
        return
    end

    local slotName = arg:match("^%s*(.-)%s*$") -- trim spaces
    if not SLOT_NAME_MAPPING[slotName] then
        print("Invalid slot name. Try one of these:")
        for _, name in ipairs({ "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands",
                                "Waist", "Legs", "Feet", "Finger", "Trinket", "One-Hand",
                                "Ranged", "Held In Off-Hand", "Off-Hand", "Two-Hand" }) do
            print("- " .. name)
        end
        return
    end

    local slotIds = GetInventorySlotsFromParsed(slotName)
    for _, slotId in ipairs(slotIds) do
        local itemLink = GetInventoryItemLink("player", slotId)
        if itemLink then
            print("Scanning: " .. itemLink)
            local parsed = ScanItem(itemLink)
            print("Slot: " .. (parsed.itemSlot or "unknown"))
            print("Item Level: " .. (parsed.itemLevel or "unknown"))
            print("Upgrade Track: " .. (parsed.itemUpgradeTrack or "none"))

            if parsed.mainStats.strength then print("Strength gear detected") end
            if parsed.mainStats.agility then print("Agility gear detected") end
            if parsed.mainStats.intellect then print("Intellect gear detected") end

            if parsed.isCraftedGear then print("Crafted") end
            if parsed.isLegacySeasonGear then print("Legacy Season") end
            if parsed.isPvPGear then print("PvP Gear") end
        else
            print("No item equipped in slot: " .. slotId)
        end
    end
end

-- Register Frame and Events
local frame = CreateFrame("Frame")
frame:RegisterEvent("LOOT_ROLLS_COMPLETE")
frame:SetScript("OnEvent", function(_, event)
    if event == "LOOT_ROLLS_COMPLETE" then
        EvaluateLootRolls()
    end
end)

-- Expose LootTrackerV2 to the global namespace
_G.LootTrackerV2 = LootTrackerV2