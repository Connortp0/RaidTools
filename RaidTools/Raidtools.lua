-- RaidTools.lua

db = _G.RaidToolsDB or {}

function SaveRaidToolsData()
    _G.RaidToolsDB = db
end

local function RefreshRTSystem()
    local group = RaidToolsUtils:GetCurrentGroupMembers()
    local name, realm = UnitName("target")
    local fullName = ""
    local hasTarget = name ~= nil and name ~= ""

    if realm == nil then
        realm = GetRealmName()
    end
    if hasTarget and name then
        fullName = name .. "-" .. realm
    end
    
    FlyoutMenu:Refresh(group, RaidToolsDB, fullName, hasTarget)

    ModeSelector:PromptIfNeeded()
end

local function OnPlayerLogin()
    print(">>RaidTools: Loaded Version " .. (C_AddOns.GetAddOnMetadata("RaidTools", "Version") or "unknown"))

    local hasLegacyBList = type(_G.BList) == "table" and next(_G.BList) ~= nil
    if not db.blacklist then db.blacklist = {} end
    if not db.strikes then db.strikes = {} end
    if db._BListMigrated == nil then db._BListMigrated = false end
    if not db.currentMode then db.currentMode = "None" end
    db._modeConfirmed = false
    SaveRaidToolsData()
    RefreshRTSystem()

    if not db._BListMigrated then
        if hasLegacyBList then
            print(">>RaidTools: Migrating legacy BList...")

            for name in pairs(_G.BList) do
                db.blacklist[name] = true
            end

            print(">>RaidTools: Migration complete.")
        else
            print(">>RaidTools: Migration already done.")
        end

        db._BListMigrated = true
        SaveRaidToolsData()
    end
end

local function OnPlayerLogout()
    db._modeConfirmed = false
    SaveRaidToolsData()
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