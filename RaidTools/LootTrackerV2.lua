-- ✅ Chat Logging Setup
local ChatFrame5 = _G["ChatFrame5"] or DEFAULT_CHAT_FRAME
print(">> RaidTools: LootTrackerV2 loaded")
ChatFrame5:AddMessage(">> RaidTools: LootTrackerV2 loaded", 1.0, 1.0, 1.0)

-- ✅ Namespace Table
local LootTrackerV2 = {}

-- ✅ Upgrade Track Order
local TRACK_ORDER = {
    Explorer = 1, Adventurer = 2,
    Veteran = 3, Champion = 4,
    Hero = 5, Myth = 6
}

-- ✅ Maximum Item Level Per Track
local TRACK_MAX_ILVL = {
    Explorer = 619, Adventurer = 632,
    Veteran = 645, Champion = 658,
    Hero = 671, Myth = 684
}

-- ✅ Curio Definitions
local CURIOS = {
    { names = { "Dreadful Bloody Gallybux", "Mystic Bloody Gallybux", "Zenith Bloody Gallybux", "Venerated Bloody Gallybux" }, slots = { "HandsCurio" } },
    { names = { "Dreadful Polished Gallybux", "Mystic Polished Gallybux", "Zenith Polished Gallybux", "Venerated Polished Gallybux" }, slots = { "ShoulderCurio" } },
    { names = { "Dreadful Rusty Gallybux", "Mystic Rusty Gallybux", "Zenith Rusty Gallybux", "Venerated Rusty Gallybux" }, slots = { "LegsCurio" } },
    { names = { "Dreadful Greased Gallybux", "Mystic Greased Gallybux", "Zenith Greased Gallybux", "Venerated Greased Gallybux" }, slots = { "ChestCurio" } },
    { names = { "Dreadful Gilded Gallybux", "Mystic Gilded Gallybux", "Zenith Gilded Gallybux", "Venerated Gilded Gallybux" }, slots = { "HeadCurio" } },
    { names = { "Excessively Bejeweled Curio" }, slots = { "FullCurio" } }
}

-- ✅ Mapping Item Slot Names to WoW Inventory Slots
local SLOT_NAME_MAPPING = {
    FullCurio = { "HEADSLOT", "SHOULDERSLOT", "CHESTSLOT", "LEGSSLOT", "HANDSSLOT" },
    Head = { "HEADSLOT" }, HeadCurio = { "HEADSLOT" },
    Neck = { "NECKSLOT" },
    Shoulder = { "SHOULDERSLOT" }, ShoulderCurio = { "SHOULDERSLOT" },
    Back = { "BACKSLOT" },
    Chest = { "CHESTSLOT" }, ChestCurio = { "CHESTSLOT" },
    Wrist = { "WRISTSLOT" },
    Hands = { "HANDSSLOT" }, HandsCurio = { "HANDSSLOT" },
    Waist = { "WAISTSLOT" },
    Legs = { "LEGSSLOT" }, LegsCurio = { "LEGSSLOT" },
    Feet = { "FEETSLOT" },
    Finger = { "FINGER0SLOT", "FINGER1SLOT" },
    Trinket = { "TRINKET0SLOT", "TRINKET1SLOT" },
    ["One-Hand"] = { "MAINHANDSLOT", "SECONDARYHANDSLOT" },
    Ranged = { "RANGEDSLOT" },
    ["Held In Off-Hand"] = { "SECONDARYHANDSLOT" },
    ["Off-Hand"] = { "SECONDARYHANDSLOT" },
    ["Two-Hand"] = { "MAINHANDSLOT" }
}

-- 🔍 Find Raid Unit By Name
local function FindRaidUnit(charName)
    for i = 1, GetNumGroupMembers() do
        local unitID = "raid" .. i
        if UnitName(unitID) == charName then
            return unitID
        end
    end
    return nil
end

-- 📈 Track Helpers
local function GetTrackOrder(track)
    return TRACK_ORDER[track] or 0
end

local function GetTrackMaxIlvl(track)
    return TRACK_MAX_ILVL[track] or 0
end

-- 🎯 Slot Resolution
local function GetInventorySlotsFromParsed(parsedSlotName)
    local tokens = SLOT_NAME_MAPPING[parsedSlotName]
    if not tokens then
        print("GISP>> No slot mapping for: " .. tostring(parsedSlotName))
        ChatFrame5:AddMessage("GISP>> No slot mapping for: " .. tostring(parsedSlotName), 1.0, 1.0, 1.0)
        return {}
    end

    local slotIds = {}
    for _, token in ipairs(tokens) do
        local slotId = GetInventorySlotInfo(token)
        if slotId then
            table.insert(slotIds, slotId)
        else
            print("GISP>> Unable to resolve slot token: " .. token)
            ChatFrame5:AddMessage("GISP>> Unable to resolve slot token: " .. token, 1.0, 1.0, 1.0)
        end
    end
    return slotIds
end

-- 🔬 Tooltip Line Parser
local function ParseTooltipLines(tooltip)
    local parsed = {
        itemLevel = nil,
        itemUpgradeTrack = nil,
        itemSlot = nil,
        mainStats = { strength = nil, agility = nil, intellect = nil },
        isLegacySeasonGear = nil,
        isCraftedGear = nil,
        isPvPGear = nil,
        isCurio = nil
    }

    local difficultyMap = {
        ["Raid Finder"] = "Veteran",
        ["Heroic"] = "Hero",
        ["Mythic"] = "Myth"
    }

    local slotMatchers = {
        "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands",
        "Waist", "Legs", "Feet", "Finger", "Trinket", "One-Hand",
        "Ranged", "Held In Off-Hand", "Off-Hand", "Two-Hand"
    }

    local regions = { tooltip:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region:GetObjectType() == "FontString" then
            local line = region:GetText()
            if line then
                -- Curio Matching
                for _, curio in ipairs(CURIOS) do
                    for _, name in ipairs(curio.names) do
                        if line:find(name, 1, true) then
                            parsed.isCurio = true
                            parsed.itemSlot = curio.slots[1]
                            for keyword, track in pairs(difficultyMap) do
                                if line:find(keyword, 1, true) then
                                    parsed.itemUpgradeTrack = track
                                    break
                                end
                            end
                            parsed.itemUpgradeTrack = parsed.itemUpgradeTrack or "Champion"
                            print("PTL>> Curio detected: " .. name .. " | Slot: " .. parsed.itemSlot .. " | Track: " .. parsed.itemUpgradeTrack)
                            ChatFrame5:AddMessage("PTL>> Curio detected: " .. name .. " | Slot: " .. parsed.itemSlot .. " | Track: " .. parsed.itemUpgradeTrack, 1.0, 1.0, 1.0)
                            return parsed
                        end
                    end
                end

                -- Standard Item Parsing
                local ilvl = line:match("Item Level (%d+)")
                if ilvl then parsed.itemLevel = tonumber(ilvl) end

                local track = line:match("Upgrade Level: (%a+) (%d+)/%d+")
                if track then parsed.itemUpgradeTrack = track end

                for _, matcher in ipairs(slotMatchers) do
                    if line:find(matcher, 1, true) then
                        parsed.itemSlot = matcher
                        print("PTL>> Matched slot: " .. matcher)
                        ChatFrame5:AddMessage("PTL>> Matched slot: " .. matcher, 1.0, 1.0, 1.0)
                        break
                    end
                end

                for _, stat in ipairs({ "Strength", "Agility", "Intellect" }) do
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

    return parsed
end

-- 🧪 Tooltip Wrapper
function ScanTooltip(tooltip, itemLink)
    local parsed = ParseTooltipLines(tooltip)
    parsed.itemLink = itemLink
    return parsed
end

-- 🧪 Tooltip Frame Setup
local lootScanTooltip = CreateFrame("GameTooltip", "LootScanTooltip", UIParent, "GameTooltipTemplate")
lootScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

-- 🧠 Safe Item Tooltip Scanner
local function ScanItem(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        print("ScanItem>> Invalid or empty item link")
        ChatFrame5:AddMessage("ScanItem>> Invalid or empty item link", 1.0, 0.5, 0.5)
        return nil
    end

    lootScanTooltip:ClearLines()
    lootScanTooltip:SetHyperlink(itemLink)
    lootScanTooltip:Show()

    return ScanTooltip(lootScanTooltip, itemLink)
end

local function IsEquippedItemBetter(equippedLinks, lootLink, callback)
    local isBetter = false
    if not equippedLinks or #equippedLinks == 0 or not lootLink then
        callback(false)
        return
    end

    local mode = _G.RaidToolsDB and _G.RaidToolsDB.rollMode or "track"
    local lootItem = Item:CreateFromItemLink(lootLink)
    local lootParsed = nil

    lootItem:ContinueOnItemLoad(function()
        lootParsed = ScanItem(lootLink)
        if lootParsed then
            print("IEIB>> --- Loot Item ---")
            ChatFrame5:AddMessage("IEIB>> --- Loot Item ---", 1.0, 1.0, 1.0)
            print("IEIB>> Link: " .. lootParsed.itemLink)
            print("IEIB>> Slot: " .. (lootParsed.itemSlot or "unknown"))
            print("IEIB>> Level: " .. (lootParsed.itemLevel or "unknown"))
            print("IEIB>> Track: " .. (lootParsed.itemUpgradeTrack or "none"))
            print("IEIB>> Stats: Str=" .. tostring(lootParsed.mainStats.strength) ..
                ", Agi=" .. tostring(lootParsed.mainStats.agility) ..
                ", Int=" .. tostring(lootParsed.mainStats.intellect))
            print("IEIB>> Crafted=" .. tostring(lootParsed.isCraftedGear) ..
                ", Legacy=" .. tostring(lootParsed.isLegacySeasonGear) ..
                ", PvP=" .. tostring(lootParsed.isPvPGear) ..
                ", Curio=" .. tostring(lootParsed.isCurio))

            ChatFrame5:AddMessage("IEIB>> Link: " .. lootParsed.itemLink, 1.0, 1.0, 1.0)
            ChatFrame5:AddMessage("IEIB>> Slot: " .. (lootParsed.itemSlot or "unknown"), 1.0, 1.0, 1.0)
            ChatFrame5:AddMessage("IEIB>> Level: " .. (lootParsed.itemLevel or "unknown"), 1.0, 1.0, 1.0)
            ChatFrame5:AddMessage("IEIB>> Track: " .. (lootParsed.itemUpgradeTrack or "none"), 1.0, 1.0, 1.0)
            ChatFrame5:AddMessage("IEIB>> Stats: Str=" .. tostring(lootParsed.mainStats.strength) ..
                ", Agi=" .. tostring(lootParsed.mainStats.agility) ..
                ", Int=" .. tostring(lootParsed.mainStats.intellect), 1.0, 1.0, 1.0)
            ChatFrame5:AddMessage("IEIB>> Crafted=" .. tostring(lootParsed.isCraftedGear) ..
                ", Legacy=" .. tostring(lootParsed.isLegacySeasonGear) ..
                ", PvP=" .. tostring(lootParsed.isPvPGear) ..
                ", Curio=" .. tostring(lootParsed.isCurio), 1.0, 1.0, 1.0)
        end

        local pending = #equippedLinks

        for _, eqLink in ipairs(equippedLinks) do
            local eqItem = Item:CreateFromItemLink(eqLink)
            eqItem:ContinueOnItemLoad(function()
                local eq = ScanItem(eqLink)
                if eq then
                    print("IEIB>> --- Equipped Item ---")
                    ChatFrame5:AddMessage("IEIB>> --- Equipped Item ---", 1.0, 1.0, 1.0)
                    print("IEIB>> Link: " .. eq.itemLink)
                    print("IEIB>> Slot: " .. (eq.itemSlot or "unknown"))
                    print("IEIB>> Level: " .. (eq.itemLevel or "unknown"))
                    print("IEIB>> Track: " .. (eq.itemUpgradeTrack or "none"))
                    print("IEIB>> Stats: Str=" .. tostring(eq.mainStats.strength) ..
                        ", Agi=" .. tostring(eq.mainStats.agility) ..
                        ", Int=" .. tostring(eq.mainStats.intellect))
                    print("IEIB>> Crafted=" .. tostring(eq.isCraftedGear) ..
                        ", Legacy=" .. tostring(eq.isLegacySeasonGear) ..
                        ", PvP=" .. tostring(eq.isPvPGear) ..
                        ", Curio=" .. tostring(eq.isCurio))

                    ChatFrame5:AddMessage("IEIB>> Link: " .. eq.itemLink, 1.0, 1.0, 1.0)
                    ChatFrame5:AddMessage("IEIB>> Slot: " .. (eq.itemSlot or "unknown"), 1.0, 1.0, 1.0)
                    ChatFrame5:AddMessage("IEIB>> Level: " .. (eq.itemLevel or "unknown"), 1.0, 1.0, 1.0)
                    ChatFrame5:AddMessage("IEIB>> Track: " .. (eq.itemUpgradeTrack or "none"), 1.0, 1.0, 1.0)
                    ChatFrame5:AddMessage("IEIB>> Stats: Str=" .. tostring(eq.mainStats.strength) ..
                        ", Agi=" .. tostring(eq.mainStats.agility) ..
                        ", Int=" .. tostring(eq.mainStats.intellect), 1.0, 1.0, 1.0)
                    ChatFrame5:AddMessage("IEIB>> Crafted=" .. tostring(eq.isCraftedGear) ..
                        ", Legacy=" .. tostring(eq.isLegacySeasonGear) ..
                        ", PvP=" .. tostring(eq.isPvPGear) ..
                        ", Curio=" .. tostring(eq.isCurio), 1.0, 1.0, 1.0)

                    -- 🧠 Comparison Logic
                    if mode == "ilvl" then
                        if eq.itemLevel < lootParsed.itemLevel then
                            isBetter = true
                        end
                    elseif mode == "track" then
                        local lootTrackMax = GetTrackMaxIlvl(lootParsed.itemUpgradeTrack)
                        if eq.isCraftedGear then
                            if eq.itemLevel < lootTrackMax then
                                isBetter = true
                            end
                        elseif GetTrackOrder(eq.itemUpgradeTrack) < GetTrackOrder(lootParsed.itemUpgradeTrack) then
                            isBetter = true
                        end
                    end
                end

                pending = pending - 1
                if pending == 0 then
                    callback(isBetter)
                end
            end)
        end
    end)
end

local function HasBetterItem(playerName, itemLink, callback)
    local unitID = FindRaidUnit(playerName)
    if not unitID then
        print("HBI>> Could not find raid unit for player: " .. playerName)
        ChatFrame5:AddMessage("HBI>> Could not find raid unit for player: " .. playerName, 1.0, 1.0, 1.0)
        callback(false)
        return
    end

    local item = Item:CreateFromItemLink(itemLink)
    item:ContinueOnItemLoad(function()
        local parsed = ScanItem(itemLink)
        if not parsed then
            print("HBI>> Failed to scan item: " .. itemLink)
            ChatFrame5:AddMessage("HBI>> Failed to scan item: " .. itemLink, 1.0, 1.0, 1.0)
            callback(false)
            return
        end

        print("HBI>> --- Target Item ---")
        ChatFrame5:AddMessage("HBI>> --- Target Item ---", 1.0, 1.0, 1.0)
        print("HBI>> Link: " .. parsed.itemLink)
        print("HBI>> Slot: " .. (parsed.itemSlot or "unknown"))
        ChatFrame5:AddMessage("HBI>> Link: " .. parsed.itemLink, 1.0, 1.0, 1.0)
        ChatFrame5:AddMessage("HBI>> Slot: " .. (parsed.itemSlot or "unknown"), 1.0, 1.0, 1.0)

        if not parsed.itemSlot then
            print("HBI>> No itemSlot found in parsed data")
            ChatFrame5:AddMessage("HBI>> No itemSlot found in parsed data", 1.0, 1.0, 1.0)
            callback(false)
            return
        end

        local equipSlots = GetInventorySlotsFromParsed(parsed.itemSlot)
        if #equipSlots == 0 then
            print("HBI>> No valid inventory slots for slot type: " .. parsed.itemSlot)
            ChatFrame5:AddMessage("HBI>> No valid inventory slots for slot type: " .. parsed.itemSlot, 1.0, 1.0, 1.0)
            callback(false)
            return
        end

        local remaining = #equipSlots
        local allBetter = true

        for _, slotID in ipairs(equipSlots) do
            local equippedLink = GetInventoryItemLink(unitID, slotID)
            IsEquippedItemBetter({equippedLink}, itemLink, function(isBetter)
                print("HBI>> Checking slot " .. slotID .. " for player " .. playerName .. ": Result = " .. tostring(isBetter))
                ChatFrame5:AddMessage("HBI>> Slot " .. slotID .. " comparison result = " .. tostring(isBetter), 1.0, 1.0, 1.0)

                if not isBetter then
                    allBetter = false
                end

                remaining = remaining - 1
                if remaining == 0 then
                    print("HBI>> All comparisons done for " .. playerName .. " | Final result: " .. tostring(allBetter))
                    ChatFrame5:AddMessage("HBI>> All comparisons done for " .. playerName .. " | Final result: " .. tostring(allBetter), 1.0, 1.0, 1.0)
                    callback(allBetter)
                end
            end)
        end
    end)
end

local processedEncounters = {}

-- Loot Rolls
local function EvaluateLootRolls()
    local encounters = C_LootHistory.GetAllEncounterInfos()

    if not encounters then
        print("ELR>> No encounter history found.")
        ChatFrame5:AddMessage("ELR>> No encounter history found.", 1.0, 1.0, 1.0)
        return
    end

    for _, encounter in ipairs(encounters) do
        if not processedEncounters[encounter.encounterID] then
            processedEncounters[encounter.encounterID] = true

            print("ELR>> Processing encounter: " .. encounter.encounterName .. " (ID: " .. encounter.encounterID .. ")")
            ChatFrame5:AddMessage("ELR>> Processing encounter: " .. encounter.encounterName .. " (ID: " .. encounter.encounterID .. ")", 1.0, 1.0, 1.0)

            local drops = C_LootHistory.GetSortedDropsForEncounter(encounter.encounterID)
            if not drops then
                print("ELR>> No drops found for encounter " .. encounter.encounterName)
                ChatFrame5:AddMessage("ELR>> No drops found for encounter " .. encounter.encounterName, 1.0, 1.0, 1.0)
            else
                for _, drop in ipairs(drops) do
                    local item = drop.itemHyperlink
                    local winnerInfo = drop.winner
                    local rollInfos = drop.rollInfos

                    print("ELR>> Evaluating item: " .. item)
                    ChatFrame5:AddMessage("ELR>> Evaluating item: " .. item, 1.0, 1.0, 1.0)

                    if item and winnerInfo and rollInfos then
                        local winnerName = winnerInfo.playerName
                        local valid = {}
                        local pending = 0

                        for _, r in ipairs(rollInfos) do
                            if r.state == Enum.EncounterLootDropRollState.NeedMainSpec then
                                print("ELR>> " .. r.playerName .. " rolled Need (" .. r.roll .. ")")
                                ChatFrame5:AddMessage("ELR>> " .. r.playerName .. " rolled Need (" .. r.roll .. ")", 1.0, 1.0, 1.0)

                                pending = pending + 1
                                HasBetterItem(r.playerName, item, function(hasBetterGear)
                                    table.insert(valid, {
                                        name = r.playerName,
                                        won = r.isWinner,
                                        roll = r.roll,
                                        hasBetterGear = hasBetterGear
                                    })

                                    pending = pending - 1
                                    if pending == 0 then
                                        table.sort(valid, function(a, b)
                                            return (a.roll or 0) > (b.roll or 0)
                                        end)

                                        print("ELR>> " .. winnerName .. " won: " .. item)
                                        ChatFrame5:AddMessage("ELR>> " .. winnerName .. " won: " .. item, 1.0, 1.0, 1.0)

                                        for _, r in ipairs(valid) do
                                            if r.hasBetterGear and not r.won then
                                                print("ELR>> " .. r.name .. " is greedy")
                                                ChatFrame5:AddMessage("ELR>> " .. r.name .. " is greedy", 1.0, 1.0, 1.0)
                                            elseif not r.hasBetterGear and r.won then
                                                for _, other in ipairs(valid) do
                                                    if not other.won and not other.hasBetterGear then
                                                        print("ELR>> " .. r.name .. " should pass " .. item .. " to " .. other.name)
                                                        ChatFrame5:AddMessage("ELR>> " .. r.name .. " should pass " .. item .. " to " .. other.name, 1.0, 1.0, 1.0)
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end)
                            end
                        end
                    else
                        print("ELR>> Incomplete drop data: item/winner/rollInfos missing")
                        ChatFrame5:AddMessage("ELR>> Incomplete drop data: item/winner/rollInfos missing", 1.0, 1.0, 1.0)
                    end
                end
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
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "LOOT_ROLLS_COMPLETE" then
        EvaluateLootRolls()
    end
end)

-- Expose LootTrackerV2 to the global namespace
_G.LootTrackerV2 = LootTrackerV2