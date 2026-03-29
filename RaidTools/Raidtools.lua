-- RaidTools.lua

_G.RaidToolsDB = _G.RaidToolsDB or {}
if not _G.RaidToolsDB.blacklist then _G.RaidToolsDB.blacklist = {} end
if not _G.RaidToolsDB.strikes then _G.RaidToolsDB.strikes = {} end
if _G.RaidToolsDB._BListMigrated == nil then _G.RaidToolsDB._BListMigrated = false end
if not _G.RaidToolsDB.currentMode then _G.RaidToolsDB.currentMode = "None" end
if not _G.RaidToolsDB.rollMode then _G.RaidToolsDB.rollMode = "track" end
if not _G.RaidToolsDB.debugMode then _G.RaidToolsDB.debugMode = false end
_G.RaidToolsDB._modeConfirmed = false

local previousInGroup = false
local previousCanUseMyGroup = nil

function RefreshRTSystem()
    local group = RaidToolsUtils:GetCurrentGroupMembers()
    local name, realm = UnitName("target")
    local fullName = ""
    local hasTarget = UnitExists("target") and UnitIsPlayer("target")

    if hasTarget and name then
        if realm == nil then
            realm = GetRealmName()
        end
        if realm and realm ~= "" then
            fullName = name .. "-" .. realm
        else
            fullName = name
        end
    end

    local inGroup = IsInGroup()
    local canUseMyGroup = RaidToolsUtils.CanUseMyGroupMode()

    if (inGroup and not previousInGroup) or (previousCanUseMyGroup == false and canUseMyGroup == true) then
        _G.RaidToolsDB._modeConfirmed = false
        if C_LFGInfo.IsInLFGDungeon() then
            _G.RaidToolsDB.currentMode = "Silent"
        end
    end
    previousInGroup = inGroup
    previousCanUseMyGroup = canUseMyGroup

    if _G.RaidToolsDB.currentMode == "My Group" and not canUseMyGroup then
        _G.RaidToolsDB.currentMode = "None"
        print(">>RaidTools: My Group mode disabled for non-leader/assistant.")
    end

    FlyoutMenu:Refresh(group, RaidToolsDB, fullName, hasTarget)

    if _G.ModeSelector and _G.ModeSelector.PromptIfNeeded then
        _G.ModeSelector:PromptIfNeeded()
    end
end

local function OnPlayerLogin()
    print(">>RaidTools: Loaded Version " .. (C_AddOns.GetAddOnMetadata("RaidTools", "Version") or "unknown"))

    local hasLegacyBList = type(_G.BList) == "table" and next(_G.BList) ~= nil

    if _G.RaidToolsDB._BListMigrated == false then
        if hasLegacyBList then
            print(">>RaidTools: Migrating legacy BList...")

            for name in pairs(_G.BList) do
                _G.RaidToolsDB.blacklist[name] = true
            end

            print(">>RaidTools: Migration complete.")
        else
            print(">>RaidTools: Migration already done.")
        end

        _G.RaidToolsDB._BListMigrated = true
        _G.RaidToolsDB._modeConfirmed = false
    end
end

local function OnAddonLoaded(addonName)
    if addonName == "RaidTools" then
        RefreshRTSystem()
    end
end

local function OnPlayerLogout()
    _G.RaidToolsDB._modeConfirmed = false
end

local function OnPlayerTargetChanged()
    RefreshRTSystem()
end

local function OnGroupRosterUpdate()
    RefreshRTSystem()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    elseif event == "ADDON_LOADED" then
        OnAddonLoaded(addonName)
    elseif event == "PLAYER_LOGOUT" then
        OnPlayerLogout()
    elseif event == "PLAYER_TARGET_CHANGED" then
        OnPlayerTargetChanged()
    elseif event == "GROUP_ROSTER_UPDATE" then
        OnGroupRosterUpdate()
    end
end)

SLASH_RAIDTOOLS1 = "/rt"
SLASH_RAIDTOOLS2 = "/raidtools"

function SlashCmdList.RAIDTOOLS(msg, editBox)
    local cmd, subcmd, arg = msg:match("^(%S*)%s*(%S*)%s*(.-)$")
    if cmd == "" then
        print(">>RaidTools Commands:")
        print("You can use /rt or /raidtools followed by a command.")
        print("/rt - Show this help message")
        print("/rt refresh - Refresh group and target info")
        print("/rt strike - List all strike entries")
        print("/rt strike add <Name-Realm> - Add a strike")
        print("/rt strike remove <Name-Realm> - Remove strikes")
        print("/rt blacklist - List blacklist entries")
        print("/rt blacklist add <Name-Realm> - Add to blacklist")
        print("/rt blacklist remove <Name-Realm> - Remove from blacklist")
        print("/rt debug <on/off> - Enables/Disables debug mode for showing RaidTools debug messages")
    elseif cmd == "refresh" then
        RefreshRTSystem()
    elseif cmd == "strike" then
        if subcmd == "" then
            for playerName, strikes in pairs(_G.RaidToolsDB.strikes) do
                print(playerName .. " has " .. strikes .. " strike(s).")
            end
        elseif subcmd == "add" then
            if arg and arg:match("^[^%-]+%-.+$") then
                local fullName = arg
                RaidToolsUtils.AddStrike(fullName, false, true)
            else
                print("Usage: /rt strike add <Name-Realm>")
            end
        elseif subcmd == "remove" then
            if arg and arg:match("^[^%-]+%-.+$") then
                local fullName = arg
                RaidToolsUtils.ClearStrikes(fullName)
            else
                print("Usage: /rt strike remove <Name-Realm>")
            end
        else
            print("Unknown subcommand for /rt strike. Use 'add' or 'remove' or '' to list striked players.")
        end
    elseif cmd == "blacklist" then
        if subcmd == "" then
            for playerName in pairs(_G.RaidToolsDB.blacklist) do
                print(playerName .. " is blacklisted.")
            end
        elseif subcmd == "add" then
            if arg and arg:match("^[^%-]+%-.+$") then
                local fullName = arg
                RaidToolsUtils.AddToBlacklist(fullName, false, false, true)
            else
                print("Usage: /rt blacklist add <Name-Realm>")
            end
        elseif subcmd == "remove" then
            if arg and arg:match("^[^%-]+%-.+$") then
                local fullName = arg
                RaidToolsUtils.RemoveFromBlacklist(fullName)
            else
                print("Usage: /rt blacklist remove <Name-Realm>")
            end
        else
            print("Unknown subcommand for /rt blacklist. Use 'add' or 'remove' or '' to list blacklisted players.")
        end
    elseif cmd == "debug" then
        if subcmd == "on" then
            _G.RaidToolsDB.debugMode = true
            print(">>RaidTools: Debug mode enabled.")
        elseif subcmd == "off" then
            _G.RaidToolsDB.debugMode = false
            print(">>RaidTools: Debug mode disabled.")
        else
            print("Unknown argument for /rt debug. Use 'on' or 'off'.")
        end
    else
        print("Unknown command: " .. cmd)
        print("Use /rt for a list of commands.")
    end
end
