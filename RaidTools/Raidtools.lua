-- RaidTools.lua

_G.RaidToolsDB = _G.RaidToolsDB or {}
if not _G.RaidToolsDB.blacklist then _G.RaidToolsDB.blacklist = {} end
if not _G.RaidToolsDB.strikes then _G.RaidToolsDB.strikes = {} end
if _G.RaidToolsDB._BListMigrated == nil then _G.RaidToolsDB._BListMigrated = false end
if not _G.RaidToolsDB.currentMode then _G.RaidToolsDB.currentMode = "None" end
if not _G.RaidToolsDB.rollMode then _G.RaidToolsDB.rollMode = "Track" end
_G.RaidToolsDB._modeConfirmed = false

function RefreshRTSystem()
    local group = RaidToolsUtils:GetCurrentGroupMembers()
    local name, realm = UnitName("target")
    local fullName = ""
    local hasTarget = name ~= nil and name ~= "" and UnitIsPlayer("target")
    
    if realm == nil then
        realm = GetRealmName()
    end
    
    if hasTarget and name and realm then
        fullName = name .. "-" .. realm
    end

    FlyoutMenu:Refresh(group, RaidToolsDB, fullName, hasTarget)

    ModeSelector:PromptIfNeeded()
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
        C_Timer.After(2, function ()
            RefreshRTSystem()
        end)
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
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    elseif event == "PLAYER_LOGOUT" then
        OnPlayerLogout()
    elseif event == "PLAYER_TARGET_CHANGED" then
        OnPlayerTargetChanged()
    elseif event == "GROUP_ROSTER_UPDATE" then
        OnGroupRosterUpdate()
    end
end)