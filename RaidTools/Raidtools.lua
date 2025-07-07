-- RaidTools.lua

print(">>RaidTools: Loaded Version " .. C_AddOns.GetAddOnMetadata("RaidTools", "Version"))
BList = _G.BList or {}

function saveBList()
    _G.BList = BList
    updatePlayerList()
end