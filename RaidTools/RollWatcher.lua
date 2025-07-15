-- RollWatcher.lua

print(">> RaidTools: RollWatcher loaded")
local db = GetRaidToolsData()
local CURRENT_SEASON = 2
local RollWatcher = {}
local db = _G.RaidToolsDB or {}
local itemModes = { "Spec", "Ilvl" }
db.rollMode = db.rollMode or "Spec"

local activeRolls = {}

--------------------------------------------------
-- 🏷 Tooltip Scanner: Tier + Season
--------------------------------------------------

function RollWatcher:GetGearTier(itemLink)
    local tiers = { "Veteran", "Champion", "Hero", "Myth" }
    local scanner = CreateFrame("GameTooltip", "RaidToolsTooltipScanner", nil, "GameTooltipTemplate")
    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    scanner:SetHyperlink(itemLink)

    for i = 2, scanner:NumLines() do
        local text = _G["RaidToolsTooltipScannerTextLeft" .. i]:GetText()
        if text then
            for _, tier in ipairs(tiers) do
                if text:find(tier .. " Equipment") then
                    return tier
                end
            end
        end
    end
    return nil
end

function RollWatcher:GetSeason(itemLink)
    local scanner = CreateFrame("GameTooltip", "RaidToolsTooltipScanner2", nil, "GameTooltipTemplate")
    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    scanner:SetHyperlink(itemLink)

    for i = 2, scanner:NumLines() do
        local text = _G["RaidToolsTooltipScanner2TextLeft" .. i]:GetText()
        if text then
            local season = text:match("Season %d+")
            if season then return season end
        end
    end
    return "Season " .. CURRENT_SEASON
end

--------------------------------------------------
-- 🧠 Spec & Upgrade Validators
--------------------------------------------------

function RollWatcher:IsMainSpec(playerName, itemLink)
    if playerName ~= UnitName("player") then return true end
    local specID = GetSpecialization()
    if not specID then return false end
    local role = GetSpecializationRole(specID)
    local stats = C_Item.GetItemStats(itemLink)
    if not stats then return false end

    if role == "DAMAGER" and (stats["ITEM_MOD_AGILITY"] or stats["ITEM_MOD_STRENGTH"] or stats["ITEM_MOD_INTELLECT"]) then return true end
    if role == "TANK" and stats["ITEM_MOD_STAMINA"] and stats["DEFENSE_SKILL_RATING"] then return true end
    if role == "HEALER" and stats["ITEM_MOD_INTELLECT"] and stats["SPELL_POWER"] then return true end
    return false
end

function RollWatcher:IsUpgrade(playerName, equipSlot, rollIlvl)
    if not equipSlot or equipSlot == "" then return false end
    local slotID = GetInventorySlotInfo(equipSlot)
    if not slotID then return false end
    local unitID = playerName == UnitName("player") and "player" or nil
    if not unitID then return false end
    local equippedLink = GetInventoryItemLink(unitID, slotID)
    if not equippedLink then return true end
    local _, _, _, equippedIlvl = C_Item.GetItemInfo(equippedLink)
    return rollIlvl > (equippedIlvl or 0)
end

--------------------------------------------------
-- 📡 Hook Events
--------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("START_LOOT_ROLL")
frame:RegisterEvent("CONFIRM_LOOT_ROLL")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "START_LOOT_ROLL" then
        local rollID = ...
        activeRolls[rollID] = true
    elseif event == "CONFIRM_LOOT_ROLL" then
        local rollID, rollType = ...
        C_Timer.After(0.5, function()
            if activeRolls[rollID] then
                local info = C_LootHistory.GetRollInfo(rollID)
                if info and info.isDone then
                    local itemLink = C_LootHistory.GetItemLink(rollID)
                    RollWatcher:AnalyzeRoll(rollID, itemLink)
                    activeRolls[rollID] = nil
                end
            end
        end)
    end
end)

--------------------------------------------------
-- 🧪 Roll Analyzer
--------------------------------------------------

function RollWatcher:AnalyzeRoll(rollID, itemLink)
    if not itemLink then return end
    local _, _, _, itemLevel, _, _, _, _, itemEquipLoc = C_Item.GetItemInfo(itemLink)
    if not itemEquipLoc or itemEquipLoc == "" then return end
    local seasonTag = RollWatcher:GetSeason(itemLink)
    local tierTag = RollWatcher:GetGearTier(itemLink)

    local validRollers = {}
    local winnerName, winnerValid

    for i = 1, C_LootHistory.GetNumPlayers(rollID) do
        local name, _, rollType, isWinner = C_LootHistory.GetPlayerInfo(rollID, i)
        if rollType == Enum.EncounterLootDropRollState.Need then
            local specOK = RollWatcher:IsMainSpec(name, itemLink)
            local ilvlOK = RollWatcher:IsUpgrade(name, itemEquipLoc, itemLevel)
            local passed = (db.rollMode == "Spec" and specOK) or (db.rollMode == "Ilvl" and ilvlOK)

            local offspecTag = (specOK or db.rollMode == "Ilvl") and nil or "(Offspec)"
            if offspecTag == "(Offspec)" then passed = true end

            local tags = {}
            if tierTag then table.insert(tags, tierTag) end
            if seasonTag then table.insert(tags, seasonTag) end
            if offspecTag then table.insert(tags, offspecTag) end
            local suffix = table.concat(tags, " ")

            print(string.format("   %s rolled on %s %s", name, itemLink, suffix))

            if isWinner then
                winnerName = name
                winnerValid = passed
            end

            table.insert(validRollers, {
                name = name,
                passed = passed,
                isWinner = isWinner
            })
        end
    end

    if winnerName and not winnerValid then
        print(string.format(">>   %s, you ninja looted on %s — watch it please.", winnerName, itemLink))
        for _, roller in ipairs(validRollers) do
            if roller.name ~= winnerName and roller.passed then
                print(string.format(">>   %s, please pass %s to %s who needs it.", winnerName, itemLink, roller.name))
                if RaidToolsUtils and RaidToolsUtils.AddStrike then
                    RaidToolsUtils.AddStrike(winnerName)
                end
                break
            end
        end
    end

    for _, roller in ipairs(validRollers) do
        if not roller.passed and not roller.isWinner then
            print(string.format(">>  %s, you ninja looted on %s — watch it please.", roller.name, itemLink))
            if RaidToolsUtils and RaidToolsUtils.AddStrike then
                RaidToolsUtils.AddStrike(roller.name)
            end
        end
    end
end

--------------------------------------------------
-- 🔚 Export
--------------------------------------------------

_G.RollWatcher = RollWatcher
