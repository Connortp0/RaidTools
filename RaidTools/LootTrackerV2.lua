local ChatFrame5 = _G["ChatFrame5"]
print(">> RaidTools: LootTrackerV2 loaded")
ChatFrame5:AddMessage(">> RaidTools: LootTrackerV2 loaded", 1.0, 1.0, 1.0)
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

local CURIOS = {
    {
        names = {
            "Dreadful Bloody Gallybux",
            "Mystic Bloody Gallybux",
            "Zenith Bloody Gallybux",
            "Venerated Bloody Gallybux"
        },
        slots = { "HandsCurio" }
    },
    {
        names = {
            "Dreadful Polished Gallybux",
            "Mystic Polished Gallybux",
            "Zenith Polished Gallybux",
            "Venerated Polished Gallybux"
        },
        slots = { "ShoulderCurio" }
    },
    {
        names = {
            "Dreadful Rusty Gallybux",
            "Mystic Rusty Gallybux",
            "Zenith Rusty Gallybux",
            "Venerated Rusty Gallybux"
        },
        slots = { "LegsCurio" }
    },
    {
        names = {
            "Dreadful Greased Gallybux",
            "Mystic Greased Gallybux",
            "Zenith Greased Gallybux",
            "Venerated Greased Gallybux"
        },
        slots = { "ChestCurio" }
    },
    {
        names = {
            "Dreadful Gilded Gallybux",
            "Mystic Gilded Gallybux",
            "Zenith Gilded Gallybux",
            "Venerated Gilded Gallybux"
        },
        slots = { "HeadCurio" }
    },
    {
        names = {
            "Excessively Bejeweled Curio"
        },
        slots = { "FullCurio" }
    }
}

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

local function FindRaidUnit(charName)
    -- Loop through raid members to find matching name
    for i = 1, GetNumGroupMembers() do
        local unitID = "raid" .. i
        local name = UnitName(unitID)

        if name and name == charName then
            return unitID
        end
    end

    -- Return nil if no match found
    return nil
end

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
        isPvPGear = nil,
        isCurio = nil
    }

    local difficultyMap = {
        ["Raid Finder"] = "Veteran",
        ["Heroic"] = "Hero",
        ["Mythic"] = "Myth"
        -- fallback: Champion
    }

    local regions = { tooltip:GetRegions() }
    if regions then
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                local line = region:GetText()
                if line then
                    -- 🧪 Curio matching with track logic
                    for _, curio in ipairs(CURIOS) do
                        for _, name in ipairs(curio.names) do
                            if line:find(name, 1, true) then
                                parsed.isCurio = true
                                parsed.itemSlot = curio.slots[1]

                                -- Detect difficulty-based upgrade track
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
                end
            end
        end
    end

    -- 🛠️ Continue with standard parsing if not a Curio
    local slotMatchers = {
        "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands",
        "Waist", "Legs", "Feet", "Finger", "Trinket", "One-Hand",
        "Ranged", "Held In Off-Hand", "Off-Hand", "Two-Hand"
    }

    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            local line = region:GetText()
            if line then
                print("PTL>> Parsing line: " .. line)
                ChatFrame5:AddMessage("PTL>> Parsing line: " .. line, 1.0, 1.0, 1.0)

                local ilvl = line:match("Item Level (%d+)")
                if ilvl then parsed.itemLevel = tonumber(ilvl) end

                local track = line:match("Upgrade Level: (%a+) (%d+)/%d+")
                if track then parsed.itemUpgradeTrack = track end

                for _, matcher in ipairs(slotMatchers) do
                    if line:find(matcher, 1, true) then
                        print("PTL>> Matched slot:", matcher)
                        ChatFrame5:AddMessage("PTL>> Matched slot: " .. matcher, 1.0, 1.0, 1.0)
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

    return parsed
end

function ScanTooltip(tooltip, itemLink)
    local parsed = ParseTooltipLines(tooltip)
    parsed.itemLink = itemLink

    return parsed
end

local lootScanTooltip = CreateFrame("GameTooltip", "LootScanTooltip", UIParent, "GameTooltipTemplate")
lootScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function ScanItem(itemLink)
    lootScanTooltip:ClearLines()
    lootScanTooltip:SetHyperlink(itemLink)
    lootScanTooltip:Show()
    
    return ScanTooltip(lootScanTooltip, itemLink)
end

local function IsEquippedItemBetter(equippedLinks, lootLink)
    if not equippedLinks or #equippedLinks == 0 or not lootLink then return false end

    local mode = _G.RaidToolsDB and _G.RaidToolsDB.rollMode or "track"

    local lootParsed = ScanItem(lootLink)
    if not lootParsed then return false end

    -- DEBUG
    print("IEIB>> Printing loot parsed data:")
    ChatFrame5:AddMessage("IEIB>> Printing loot parsed data:", 1.0, 1.0, 1.0)
    print("IEIB>> Item Link: " .. lootParsed.itemLink)
    ChatFrame5:AddMessage("IEIB>> Item Link: " .. lootParsed.itemLink, 1.0, 1.0, 1.0)
    print("IEIB>> Item Slot: " .. (lootParsed.itemSlot or "unknown"))
    ChatFrame5:AddMessage("IEIB>> Item Slot: " .. (lootParsed.itemSlot or "unknown"), 1.0, 1.0, 1.0)
    print("IEIB>> Item Level: " .. (lootParsed.itemLevel or "unknown"))
    ChatFrame5:AddMessage("IEIB>> Item Level: " .. (lootParsed.itemLevel or "unknown"), 1.0, 1.0, 1.0)
    print("IEIB>> Item Upgrade Track: " .. (lootParsed.itemUpgradeTrack or "none"))
    ChatFrame5:AddMessage("IEIB>> Item Upgrade Track: " .. (lootParsed.itemUpgradeTrack or "none"), 1.0, 1.0, 1.0)
    print("IEIB>> Main Stats: Strength=" .. tostring(lootParsed.mainStats.strength) ..
          ", Agility=" .. tostring(lootParsed.mainStats.agility) ..
          ", Intellect=" .. tostring(lootParsed.mainStats.intellect))
    ChatFrame5:AddMessage("IEIB>> Main Stats: Strength=" .. tostring(lootParsed.mainStats.strength) ..
          ", Agility=" .. tostring(lootParsed.mainStats.agility) ..
          ", Intellect=" .. tostring(lootParsed.mainStats.intellect), 1.0, 1.0, 1.0)
    print("IEIB>> Is Crafted Gear: " .. tostring(lootParsed.isCraftedGear))
    ChatFrame5:AddMessage("IEIB>> Is Crafted Gear: " .. tostring(lootParsed.isCraftedGear), 1.0, 1.0, 1.0)
    print("IEIB>> Is Legacy Season Gear: " .. tostring(lootParsed.isLegacySeasonGear))
    ChatFrame5:AddMessage("IEIB>> Is Legacy Season Gear: " .. tostring(lootParsed.isLegacySeasonGear), 1.0, 1.0, 1.0)
    print("IEIB>> Is PvP Gear: " .. tostring(lootParsed.isPvPGear))
    ChatFrame5:AddMessage("IEIB>> Is PvP Gear: " .. tostring(lootParsed.isPvPGear), 1.0, 1.0, 1.0)
    print("IEIB>> Is Curio: " .. tostring(lootParsed.isCurio))
    ChatFrame5:AddMessage("IEIB>> Is Curio: " .. tostring(lootParsed.isCurio), 1.0, 1.0, 1.0)

    -- Equipped PvP or Legacy Season gear: loot is always better
    for _, eqLink in ipairs(equippedLinks) do
        local eq = ScanItem(eqLink)
        print("IEIB>> Printing equipped item parsed data:")
        ChatFrame5:AddMessage("IEIB>> Printing equipped item parsed data:", 1.0, 1.0, 1.0)
        print("IEIB>> Item Link: " .. eq.itemLink)
        ChatFrame5:AddMessage("IEIB>> Item Link: " .. eq.itemLink, 1.0, 1.0, 1.0)
        print("IEIB>> Item Slot: " .. (eq.itemSlot or "unknown"))
        ChatFrame5:AddMessage("IEIB>> Item Slot: " .. (eq.itemSlot or "unknown"), 1.0, 1.0, 1.0)
        print("IEIB>> Item Level: " .. (eq.itemLevel or "unknown"))
        ChatFrame5:AddMessage("IEIB>> Item Level: " .. (eq.itemLevel or "unknown"), 1.0, 1.0, 1.0)
        print("IEIB>> Item Upgrade Track: " .. (eq.itemUpgradeTrack or "none"))
        ChatFrame5:AddMessage("IEIB>> Item Upgrade Track: " .. (eq.itemUpgradeTrack or "none"), 1.0, 1.0, 1.0)
        print("IEIB>> Main Stats: Strength=" .. tostring(eq.mainStats.strength) ..
              ", Agility=" .. tostring(eq.mainStats.agility) ..
              ", Intellect=" .. tostring(eq.mainStats.intellect))
        ChatFrame5:AddMessage("IEIB>> Main Stats: Strength=" .. tostring(eq.mainStats.strength) ..
                ", Agility=" .. tostring(eq.mainStats.agility) ..
                ", Intellect=" .. tostring(eq.mainStats.intellect), 1.0, 1.0, 1.0)
        print("IEIB>> Is Crafted Gear: " .. tostring(eq.isCraftedGear))
        ChatFrame5:AddMessage("IEIB>> Is Crafted Gear: " .. tostring(eq.isCraftedGear), 1.0, 1.0, 1.0)
        print("IEIB>> Is Legacy Season Gear: " .. tostring(eq.isLegacySeasonGear))
        ChatFrame5:AddMessage("IEIB>> Is Legacy Season Gear: " .. tostring(eq.isLegacySeasonGear), 1.0, 1.0, 1.0)
        print("IEIB>> Is PvP Gear: " .. tostring(eq.isPvPGear))
        ChatFrame5:AddMessage("IEIB>> Is PvP Gear: " .. tostring(eq.isPvPGear), 1.0, 1.0, 1.0)
        print("IEIB>> Is Curio: " .. tostring(eq.isCurio))
        ChatFrame5:AddMessage("IEIB>> Is Curio: " .. tostring(eq.isCurio), 1.0, 1.0, 1.0)
        
        if eq and (eq.isPvPGear or eq.isLegacySeasonGear) then
            return false
        end
    end

    -- Standard comparison across all equipped items in matching slots
    for _, eqLink in ipairs(equippedLinks) do
        local eq = ScanItem(eqLink)
        if eq then
            if mode == "ilvl" then
                if eq.itemLevel < lootParsed.itemLevel then
                    return true
                end
            elseif mode == "track" then
                local lootTrackMax = GetTrackMaxIlvl(lootParsed.itemUpgradeTrack)
                if eq.isCraftedGear then
                    if eq.itemLevel < lootTrackMax then
                        return true
                    end
                else
                    if GetTrackOrder(eq.itemUpgradeTrack) < GetTrackOrder(lootParsed.itemUpgradeTrack) then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function HasBetterItem(playerName, itemLink)
    local unitID = FindRaidUnit(playerName)
    if not unitID then
        print("HBI>> Could not find raid unit for player:", playerName)
        ChatFrame5:AddMessage("HBI>> Could not find raid unit for player: " .. playerName, 1.0, 1.0, 1.0)
        return false
    end

    local parsed = ScanItem(itemLink)
    if not parsed or not parsed.itemSlot then
        print("HBI>> Unable to parse item slot from:", itemLink)
        ChatFrame5:AddMessage("HBI>> Unable to parse item slot from: " .. itemLink, 1.0, 1.0, 1.0)
        return false
    end

    local equipSlots = GetInventorySlotsFromParsed(parsed.itemSlot)
    if #equipSlots == 0 then
        print("HBI>> No valid inventory slots for:", parsed.itemSlot)
        ChatFrame5:AddMessage("HBI>> No valid inventory slots for: " .. parsed.itemSlot, 1.0, 1.0, 1.0)
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
            if drops then
                for _, drop in ipairs(drops) do
                    local item = drop.itemHyperlink
                    local winnerInfo = drop.winner
                    local rollInfos = drop.rollInfos

                    print("ELR>> Item: " .. item)
                    ChatFrame5:AddMessage("ELR>> Item: " .. item, 1.0, 1.0, 1.0)

                    if item and winnerInfo and rollInfos then
                        local winnerName = winnerInfo.playerName
                        local valid = {}

                        for _, r in ipairs(rollInfos) do
                            if r.state == Enum.EncounterLootDropRollState.NeedMainSpec then
                                print("ELR>> " .. r.playerName .. " rolled (" .. r.roll .. ") Need on " .. item)
                                ChatFrame5:AddMessage("ELR>> " .. r.playerName .. " rolled (" .. r.roll .. ") Need on " .. item, 1.0, 1.0, 1.0)
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

                        print("ELR>> " .. winnerName .. " won the item: " .. item)
                        ChatFrame5:AddMessage("ELR>> " .. winnerName .. " won the item: " .. item, 1.0, 1.0, 1.0)

                        for _, r in ipairs(valid) do
                            if r.hasBetterGear == true and r.won == false then
                                print("ELR>> " .. r.name .. " is greedy")
                                ChatFrame5:AddMessage("ELR>> " .. r.name .. " is greedy", 1.0, 1.0, 1.0)
                            elseif r.hasBetterGear == false and r.won == true then
                                for _, other in ipairs(valid) do
                                    if other.won == false and other.hasBetterGear == false then
                                        print("ELR>> " .. r.name .. " pass " .. item .. " to the next roller who needs it " .. other.name)
                                        ChatFrame5:AddMessage("ELR>> " .. r.name .. " pass " .. item .. " to the next roller who needs it " .. other.name, 1.0, 1.0, 1.0)
                                        break
                                    end
                                end
                            end
                        end
                    else
                        print("ELR>> Missing item/winner/rollInfos in drop data.")
                        ChatFrame5:AddMessage("ELR>> Missing item/winner/rollInfos in drop data.", 1.0, 1.0, 1.0)
                    end
                end
            else
                print("ELR>> No drops found for encounter " .. encounter.encounterName .. " (ID: " .. encounter.encounterID .. ")")
                ChatFrame5:AddMessage("ELR>> No drops found for encounter " .. encounter.encounterName .. " (ID: " .. encounter.encounterID .. ")", 1.0, 1.0, 1.0)
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