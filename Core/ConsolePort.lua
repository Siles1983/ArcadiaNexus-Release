--[[
    ArcadiaNexus – Core/ConsolePort.lua

    Phase-1-Brücke zu ConsolePort (https://github.com/seblindfors/ConsolePort).
    Ohne ConsolePort oder mit ausgeschaltetem Setting: No-Op.

    Öffentliche API:
        ArcadiaNexus.HasConsolePort()
        ArcadiaNexus.ConsolePortBridge.HasAddon()
        ArcadiaNexus.ConsolePortBridge.IsSettingEnabled()
        ArcadiaNexus.ConsolePortBridge.IsActive()
        ArcadiaNexus.ConsolePortBridge.SetEnabled(bool)
        ArcadiaNexus.ConsolePortBridge.Sync()
        ArcadiaNexus.ConsolePortBridge.Init()
]]

local ArcadiaNexus = _G.ArcadiaNexus
local Bridge = {}
ArcadiaNexus.ConsolePortBridge = Bridge

Bridge.SETTING_KEY = "consolePortCursor"
Bridge.DEFAULT_ENABLED = true

local HUB_FRAME_NAME = "NexusMainFrame"
local registered = {}

local function IsAddOnLoadedSafe(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name) == true
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded(name) == true
    end
    return false
end

local function CursorAPI()
    local cp = _G.ConsolePort
    if type(cp) ~= "table" then
        return nil
    end
    if type(cp.AddInterfaceCursorFrame) ~= "function" then
        return nil
    end
    return cp
end

function Bridge.HasAddon()
    if IsAddOnLoadedSafe("ConsolePort") then
        return true
    end
    return CursorAPI() ~= nil
end

function Bridge.IsSettingEnabled()
    local CS = ArcadiaNexus.ClientSettingsStore
    if not CS or not CS.GetFlag then
        return Bridge.DEFAULT_ENABLED
    end
    return CS.GetFlag(Bridge.SETTING_KEY, Bridge.DEFAULT_ENABLED) == true
end

function Bridge.IsActive()
    return Bridge.HasAddon() and Bridge.IsSettingEnabled()
end

local function UnregisterFrame(cp, frame)
    if not frame then
        return
    end
    if cp and type(cp.RemoveInterfaceCursorFrame) == "function" then
        pcall(cp.RemoveInterfaceCursorFrame, cp, frame)
    end
    registered[frame] = nil
end

function Bridge.UnregisterAll()
    local cp = CursorAPI()
    local frames = {}
    for frame in pairs(registered) do
        frames[#frames + 1] = frame
    end
    for i = 1, #frames do
        UnregisterFrame(cp, frames[i])
    end
end

function Bridge.RegisterFrame(frame)
    if not frame or not Bridge.IsActive() then
        return false
    end
    local cp = CursorAPI()
    if not cp then
        return false
    end
    local ok, result = pcall(cp.AddInterfaceCursorFrame, cp, frame)
    if ok and result ~= false then
        registered[frame] = true
        return true
    end
    return false
end

function Bridge.RegisterHub()
    local hub = _G[HUB_FRAME_NAME]
    if hub then
        return Bridge.RegisterFrame(hub)
    end
    return false
end

function Bridge.Sync()
    if not Bridge.IsActive() then
        Bridge.UnregisterAll()
        return false
    end
    return Bridge.RegisterHub()
end

function Bridge.SetEnabled(enabled)
    local CS = ArcadiaNexus.ClientSettingsStore
    if CS and CS.SetFlag then
        CS.SetFlag(Bridge.SETTING_KEY, enabled and true or false)
    end
    Bridge.Sync()
    return Bridge.IsActive()
end

function Bridge.OnHubShown(frame)
    if frame then
        Bridge.RegisterFrame(frame)
    else
        Bridge.RegisterHub()
    end
    local cp = CursorAPI()
    if cp and type(cp.SetCursorNodeIfActive) == "function" and frame then
        pcall(cp.SetCursorNodeIfActive, cp, frame)
    end
end

local CAPTURE_BUTTONS = {
    "PADLEFT", "PADRIGHT", "PADUP", "PADDOWN",
    "PADDLEFT", "PADDRIGHT", "PADDUP", "PADDDOWN",
    "PAD1", "PAD2", "PAD3", "PAD4",
    "PADLSHOULDER", "PADRSHOULDER",
    "PADBACK", "PADFORWARD", "PADSOCIAL", "PAD6",
}

function Bridge.SetGameplayCapture(enabled, onButton)
    local cp = _G.ConsolePort
    local hub = _G[HUB_FRAME_NAME]
    if cp and type(cp.SetCursorObstructor) == "function" and hub then
        pcall(cp.SetCursorObstructor, cp, hub, enabled and true or nil)
    end

    local db = cp and type(cp.GetData) == "function" and cp:GetData() or nil
    local Input = db and db.Input
    if not Input then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    if not enabled then
        if type(Input.Release) == "function" and hub then
            pcall(Input.Release, Input, hub)
        end
        return
    end
    if type(Input.SetCommand) ~= "function" or not hub then
        return
    end
    for i = 1, #CAPTURE_BUTTONS do
        local id = CAPTURE_BUTTONS[i]
        pcall(function()
            Input:SetCommand(id, hub, true, nil, "ArcadiaPad", function(_, state)
                if onButton then
                    onButton(id, state and true or false)
                end
            end)
        end)
    end
end

function Bridge.Init()
    Bridge.Sync()
    if CreateFrame then
        local watcher = CreateFrame("Frame")
        watcher:RegisterEvent("ADDON_LOADED")
        watcher:SetScript("OnEvent", function(_, _, name)
            if name == "ConsolePort" or name == "ConsolePort_Cursor" then
                Bridge.Sync()
            end
        end)
    end
    if GH_LogInfo then
        GH_LogInfo("ConsolePort", Bridge.IsActive()
            and "Cursor-Stack aktiv"
            or (Bridge.HasAddon() and "ConsolePort erkannt, Schalter aus" or "ConsolePort nicht geladen"))
    end
end
