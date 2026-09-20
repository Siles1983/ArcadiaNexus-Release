--[[
    ArcadiaNexus – Core/GameInput.lua

    Phase-2-Gamepad: während einer Session D-Pad/Stick auf bestehende
    Engine-Handler legen. ConsolePort-Cursor wird per Obstructor geblockt.

    Ohne ConsolePort / ausgeschaltetem Setting: No-Op.
]]

local ArcadiaNexus = _G.ArcadiaNexus
local GI = {}
ArcadiaNexus.GameInput = GI

local DEADZONE = 0.35
local CAPTURE_BUTTONS = {
    "PADLEFT", "PADRIGHT", "PADUP", "PADDOWN",
    "PADDLEFT", "PADDRIGHT", "PADDUP", "PADDDOWN",
    "PAD1", "PAD2", "PAD3", "PAD4",
    "PADLSHOULDER", "PADRSHOULDER",
    "PADBACK", "PADFORWARD", "PADSOCIAL", "PAD6",
}

local BUTTON_ALIASES = {
    PADDLEFT  = "PADLEFT",
    PADDRIGHT = "PADRIGHT",
    PADDUP    = "PADUP",
    PADDDOWN  = "PADDOWN",
}

-- PS: Circle / Create / Back. Xbox: B / View.
local EXIT_BUTTONS = {
    PAD2     = true,
    PADBACK  = true,
    PADSOCIAL = true,
    PAD6     = true,
}

local function NormalizeButton(button)
    if not button then return button end
    button = string.upper(tostring(button))
    return BUTTON_ALIASES[button] or button
end

GI._activeGameId = nil
GI._profile      = nil
GI._held         = {}
GI._axis         = { x = 0, y = 0 }
GI._axisHold     = { left = false, right = false, up = false, down = false }
GI._hooksInstalled = false
GI._captureFrame = nil
GI._overlayMode  = false
GI._menuButtons  = nil
GI._menuIndex    = 1
GI._menuHighlight = nil
GI._overlayStack  = {}
GI._overlayCancel = nil

local function Engine(key)
    return key and ArcadiaNexus[key] or nil
end

local function IsLeftStick(stick)
    if not stick then return false end
    stick = tostring(stick)
    return stick == "Left" or stick == "LStick" or stick == "Movement" or stick == "1"
end

local function SyncHold(name, want, press, release)
    local prev = GI._axisHold[name]
    if want == prev then return end
    GI._axisHold[name] = want
    if want then
        if press then press() end
    else
        if release then release() end
    end
end

local function SyncDir4(E, downFn, upFn, x, y)
    SyncHold("left",  x < -DEADZONE, function() downFn(E, "LEFT") end,  function() upFn(E, "LEFT") end)
    SyncHold("right", x >  DEADZONE, function() downFn(E, "RIGHT") end, function() upFn(E, "RIGHT") end)
    SyncHold("up",    y >  DEADZONE, function() downFn(E, "UP") end,    function() upFn(E, "UP") end)
    SyncHold("down",  y < -DEADZONE, function() downFn(E, "DOWN") end,  function() upFn(E, "DOWN") end)
end

local function DirTap(E, btn, pressed, send)
    if not pressed then return end
    if     btn == "PADLEFT"  then send(E, "LEFT")
    elseif btn == "PADRIGHT" then send(E, "RIGHT")
    elseif btn == "PADUP"    then send(E, "UP")
    elseif btn == "PADDOWN"  then send(E, "DOWN")
    end
end

local function HoldKeyPair(E, btn, pressed, downFn, upFn)
    local key
    if     btn == "PADLEFT"  then key = "LEFT"
    elseif btn == "PADRIGHT" then key = "RIGHT"
    elseif btn == "PADUP"    then key = "UP"
    elseif btn == "PADDOWN"  then key = "DOWN"
    end
    if not key then return false end
    if pressed then downFn(E, key) else upFn(E, key) end
    return true
end

-- Kein Eintrag = kein Stick/D-Pad-Gameplay (Klickspiele nutzen den Hub-Cursor).
-- Noch in Entwicklung, bewusst ohne Profil:
-- AZEROTHFIGHTERS, DARKMOON_PINBALL, Arcane Barrage, AZEROTH_ASCENT, TINKERSREVENGE
local PROFILES = {
    BLOCKBREAKER = {
        engine = "BB_Engine",
        analog = "x",
        onButton = function(E, btn, pressed)
            if btn == "PADLEFT" then
                E:HandleKey(pressed and "LEFT_DOWN" or "LEFT_UP")
            elseif btn == "PADRIGHT" then
                E:HandleKey(pressed and "RIGHT_DOWN" or "RIGHT_UP")
            elseif (btn == "PAD1" or btn == "PADFORWARD" or btn == "PAD4") and pressed then
                E:HandleKey("PAUSE")
            end
        end,
        onAxis = function(E, x)
            SyncHold("left",  x < -DEADZONE,
                function() E:HandleKey("LEFT_DOWN") end,
                function() E:HandleKey("LEFT_UP") end)
            SyncHold("right", x > DEADZONE,
                function() E:HandleKey("RIGHT_DOWN") end,
                function() E:HandleKey("RIGHT_UP") end)
        end,
    },
    ALIENDEFENSE = {
        engine = "AD_Engine",
        analog = "x",
        onButton = function(E, btn, pressed)
            local gs = E.gameState
            if btn == "PADLEFT" then
                if gs then gs.keyLeft = pressed end
            elseif btn == "PADRIGHT" then
                if gs then gs.keyRight = pressed end
            elseif btn == "PAD1" then
                if gs then gs.keyFire = pressed end
            elseif btn == "PADUP" and pressed and E.CycleWeaponUp then
                E:CycleWeaponUp()
            elseif btn == "PADDOWN" and pressed and E.CycleWeaponDown then
                E:CycleWeaponDown()
            elseif (btn == "PADFORWARD" or btn == "PAD4") and pressed and E.TogglePause then
                E:TogglePause()
            end
        end,
        onAxis = function(E, x)
            local gs = E.gameState
            if not gs then return end
            gs.keyLeft  = x < -DEADZONE
            gs.keyRight = x >  DEADZONE
        end,
    },
    ARGUSORBDEFENSE = {
        engine = "AOD_Engine",
        analog = "xy",
        onButton = function(E, btn, pressed)
            if btn == "PADLEFT" then
                E:HandleKey("ROTATE_LEFT", pressed)
            elseif btn == "PADRIGHT" then
                E:HandleKey("ROTATE_RIGHT", pressed)
            elseif btn == "PADUP" or btn == "PADLSHOULDER" then
                E:HandleKey("THRUST", pressed)
            elseif btn == "PAD1" then
                E:HandleKey("FIRE", pressed)
            elseif (btn == "PADFORWARD" or btn == "PAD4") and pressed then
                E:HandleKey("PAUSE", true)
            end
        end,
        onAxis = function(E, x, y)
            E:HandleKey("ROTATE_LEFT",  x < -DEADZONE)
            E:HandleKey("ROTATE_RIGHT", x >  DEADZONE)
            E:HandleKey("THRUST",       y >  DEADZONE)
        end,
    },
    SNAKE = {
        engine = "SNK_Engine",
        onButton = function(E, btn, pressed)
            DirTap(E, btn, pressed, function(eng, dir)
                eng:HandleKey(dir)
            end)
        end,
    },
    ["2048"] = {
        engine = "TDG_Engine",
        onButton = function(E, btn, pressed)
            DirTap(E, btn, pressed, function(eng, dir)
                eng:HandlePlayerMove(dir)
            end)
        end,
    },
    BLOCKDROP = {
        engine = "BLD_Engine",
        onButton = function(E, btn, pressed)
            if not pressed then return end
            if     btn == "PADLEFT"  then E:HandlePlayKey("LEFT")
            elseif btn == "PADRIGHT" then E:HandlePlayKey("RIGHT")
            elseif btn == "PADUP"    then E:HandlePlayKey("UP")
            elseif btn == "PADDOWN"  then E:HandlePlayKey("DOWN")
            elseif btn == "PAD1"     then E:HandlePlayKey("SPACE")
            end
        end,
    },
    GOBLINBLAST = {
        engine = "GB_Engine",
        analog = "xy",
        onButton = function(E, btn, pressed)
            if btn == "PAD1" then
                if pressed then E:HandleKeyDown("SPACE") end
                return
            end
            if btn == "PADFORWARD" and pressed then
                E:HandleKeyDown("ESCAPE")
                return
            end
            HoldKeyPair(E, btn, pressed,
                function(eng, key) eng:HandleKeyDown(key) end,
                function(eng, key) eng:HandleKeyUp(key) end)
        end,
        onAxis = function(E, x, y)
            SyncDir4(E,
                function(eng, key) eng:HandleKeyDown(key) end,
                function(eng, key) eng:HandleKeyUp(key) end,
                x, y)
        end,
    },
    BARREL_BRAWL = {
        engine = "BRB_Engine",
        analog = "xy",
        onButton = function(E, btn, pressed)
            if btn == "PAD1" then
                if pressed then E:HandleKeyDown("SPACE") end
                return
            end
            if (btn == "PADFORWARD" or btn == "PAD4") and pressed then
                E:HandleKeyDown("P")
                return
            end
            HoldKeyPair(E, btn, pressed,
                function(eng, key) eng:HandleKeyDown(key) end,
                function(eng, key) eng:HandleKeyUp(key) end)
        end,
        onAxis = function(E, x, y)
            SyncDir4(E,
                function(eng, key) eng:HandleKeyDown(key) end,
                function(eng, key) eng:HandleKeyUp(key) end,
                x, y)
        end,
    },
    REACTIONSTRIKE = {
        engine = "RS_Engine",
        onButton = function(E, btn, pressed)
            if pressed and (btn == "PAD1" or btn == "PADRSHOULDER") then
                E:HandleInput("STRIKE")
            end
        end,
    },
    NONOGRAM = {
        engine = "NON_Engine",
        onButton = function(E, btn, pressed)
            if not pressed then return end
            if     btn == "PADUP"    then E:MoveCursor(-1,  0)
            elseif btn == "PADDOWN"  then E:MoveCursor( 1,  0)
            elseif btn == "PADLEFT"  then E:MoveCursor( 0, -1)
            elseif btn == "PADRIGHT" then E:MoveCursor( 0,  1)
            elseif btn == "PAD1"     then E:HandleKeyAction("FILL")
            elseif btn == "PAD3"     then E:HandleKeyAction("MARK")
            elseif btn == "PAD4"     then E:HandleKeyAction("TOGGLE_MODE")
            end
        end,
    },
    BUBBLESHOOTER = {
        engine = "BS_Engine",
        analog = "xy",
        onButton = function(E, btn, pressed)
            if not pressed then return end
            if btn == "PAD1" then
                E:Fire()
            elseif btn == "PADFORWARD" or btn == "PAD4" then
                if E.SaveAndPause then E:SaveAndPause() end
            end
        end,
        onAxis = function(_, x, y)
            local R = ArcadiaNexus.BS_Renderer
            if R and R.SetPadAim then
                R:SetPadAim(x, y)
            end
        end,
    },
}

GI.PROFILES = PROFILES

local function Bridge()
    return ArcadiaNexus.ConsolePortBridge
end

function GI.IsEnabled()
    local B = Bridge()
    return B and B.IsActive() == true
end

function GI.HasProfile(gameId)
    return gameId ~= nil and PROFILES[gameId] ~= nil
end

local function ResetHolds()
    for k in pairs(GI._held) do
        GI._held[k] = nil
    end
    GI._axis.x, GI._axis.y = 0, 0
    GI._axisHold.left = false
    GI._axisHold.right = false
    GI._axisHold.up = false
    GI._axisHold.down = false
end

local function EnsureCaptureFrame()
    if GI._captureFrame or not CreateFrame then
        return GI._captureFrame
    end
    local f = CreateFrame("Frame", "ArcadiaNexus_GamePadCapture", UIParent)
    f:SetSize(1, 1)
    f:SetPoint("CENTER")
    f:Hide()
    if f.EnableGamePadButton then
        f:EnableGamePadButton(true)
    end
    if f.EnableGamePadStick then
        f:EnableGamePadStick(true)
    end
    f:SetScript("OnGamePadButtonDown", function(_, button)
        GI.HandleButton(button, true)
    end)
    f:SetScript("OnGamePadButtonUp", function(_, button)
        GI.HandleButton(button, false)
    end)
    f:SetScript("OnGamePadStick", function(_, stick, x, y)
        GI.HandleStick(stick, x, y)
    end)
    f:SetScript("OnUpdate", function()
        GI.Poll()
    end)
    GI._captureFrame = f
    return f
end

local function ClickFrame(btn)
    if not btn then return false end
    if btn.Click then
        btn:Click("LeftButton")
        return true
    end
    if btn.GetScript then
        local fn = btn:GetScript("OnClick")
        if fn then
            fn(btn, "LeftButton")
            return true
        end
    end
    return false
end

local function HighlightMenu(index)
    local buttons = GI._menuButtons
    if not buttons or #buttons == 0 then return end
    if index < 1 then index = #buttons end
    if index > #buttons then index = 1 end
    local prev = GI._menuHighlight
    if prev and prev.GetScript then
        local leave = prev:GetScript("OnLeave")
        if leave then leave(prev) end
    end
    local btn = buttons[index]
    GI._menuIndex = index
    GI._menuHighlight = btn
    if btn and btn.GetScript then
        local enter = btn:GetScript("OnEnter")
        if enter then enter(btn) end
    end
end

function GI.RequestExit()
    local GS = ArcadiaNexus.GameSession
    local cur = GS and GS.GetCurrent and GS:GetCurrent()
    local gameId = (cur and cur.gameId) or GI._activeGameId
    local GR = ArcadiaNexus.GameRegistry
    local renderer = GR and GR.GetRenderer and gameId and GR.GetRenderer(gameId)
    if renderer then
        local btn = renderer._exitBtn or renderer.exitBtn
        if btn and (not btn.IsShown or btn:IsShown()) then
            if ClickFrame(btn) then return true end
        end
        if renderer.EnterIdleState then
            local E = GI._profile and Engine(GI._profile.engine)
            if E and E.SaveAndPause then
                E:SaveAndPause()
            elseif E and E.StopGame then
                E:StopGame()
            end
            renderer:EnterIdleState()
            return true
        end
    end
    local E = GI._profile and Engine(GI._profile.engine)
    if E then
        if E.SaveAndPause then
            E:SaveAndPause()
            return true
        end
        if E.StopGame then
            E:StopGame()
            return true
        end
    end
    if GR and GR.StopActiveGame then
        GR.StopActiveGame()
        return true
    end
    return false
end

function GI.HandleMenuButton(button)
    local buttons = GI._menuButtons
    if not buttons or #buttons == 0 then
        return GI.RequestExit()
    end
    if button == "PADLEFT" or button == "PADUP" then
        HighlightMenu(GI._menuIndex - 1)
        return true
    end
    if button == "PADRIGHT" or button == "PADDOWN" then
        HighlightMenu(GI._menuIndex + 1)
        return true
    end
    if button == "PAD1" then
        return ClickFrame(buttons[GI._menuIndex] or buttons[1])
    end
    if button == "PAD2" or button == "PADBACK" or button == "PADSOCIAL" or button == "PAD6" then
        if GI._overlayCancel then
            GI._overlayCancel()
            return true
        end
        return ClickFrame(buttons[#buttons])
    end
    return false
end

function GI.OnUiOverlay(buttons, opts)
    if not GI.IsEnabled() then return false end
    opts = opts or {}
    if GI._overlayMode then
        local stack = GI._overlayStack
        stack[#stack + 1] = {
            buttons = GI._menuButtons,
            index   = GI._menuIndex,
            cancel  = GI._overlayCancel,
        }
    end
    GI._overlayMode = true
    GI._menuButtons = buttons or {}
    GI._overlayCancel = opts.onCancel
    GI._menuIndex = 1
    GI._menuHighlight = nil
    GI.ReleaseAll()
    local f = EnsureCaptureFrame()
    if f then
        f:Show()
        if f.EnableGamePadButton then f:EnableGamePadButton(true) end
    end
    local B = Bridge()
    if B and B.SetGameplayCapture then
        B.SetGameplayCapture(true, GI.HandleButton)
    end
    HighlightMenu(1)
    return true
end

function GI.OnUiOverlayClosed()
    if not GI._overlayMode then return end
    ResetHolds()
    local stack = GI._overlayStack
    local prev = stack[#stack]
    if prev then
        stack[#stack] = nil
        GI._menuButtons = prev.buttons
        GI._overlayCancel = prev.cancel
        GI._menuHighlight = nil
        HighlightMenu(prev.index or 1)
        return
    end
    GI._overlayMode = false
    GI._menuButtons = nil
    GI._overlayCancel = nil
    GI._menuHighlight = nil
    if GI._profile then
        local B = Bridge()
        if B and B.SetGameplayCapture then
            B.SetGameplayCapture(true, GI.HandleButton)
        end
        return
    end
    GI.Stop()
end

function GI.HandleButton(button, pressed)
    button = NormalizeButton(button)
    pressed = pressed and true or false
    if GI._held[button] == pressed then
        return true
    end
    GI._held[button] = pressed
    if GI._overlayMode then
        if pressed then
            return GI.HandleMenuButton(button)
        end
        return true
    end
    if pressed and EXIT_BUTTONS[button] then
        return GI.RequestExit()
    end
    local profile = GI._profile
    if not profile or not profile.onButton then return false end
    local E = Engine(profile.engine)
    if not E then return false end
    profile.onButton(E, button, pressed)
    return true
end

function GI.HandleStick(stick, x, y)
    if GI._overlayMode then return false end
    if not IsLeftStick(stick) and stick ~= nil then
        return false
    end
    local profile = GI._profile
    if not profile or not profile.onAxis then return false end
    local E = Engine(profile.engine)
    if not E then return false end
    x = tonumber(x) or 0
    y = tonumber(y) or 0
    GI._axis.x, GI._axis.y = x, y
    if profile.analog == "x" then
        profile.onAxis(E, x)
    else
        profile.onAxis(E, x, y)
    end
    return true
end

function GI.Poll()
    if GI._overlayMode then
        if IsGamePadButtonDown then
            for i = 1, #CAPTURE_BUTTONS do
                local btn = CAPTURE_BUTTONS[i]
                local down = IsGamePadButtonDown(btn) == true
                if GI._held[btn] ~= down then
                    GI.HandleButton(btn, down)
                end
            end
        end
        return
    end
    if not GI._profile then return end
    if IsGamePadButtonDown then
        for i = 1, #CAPTURE_BUTTONS do
            local btn = CAPTURE_BUTTONS[i]
            local down = IsGamePadButtonDown(btn) == true
            if GI._held[btn] ~= down then
                GI.HandleButton(btn, down)
            end
        end
    end
    if C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetActiveDeviceID then
        local ok, state = pcall(function()
            return C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID())
        end)
        if ok and type(state) == "table" and type(state.sticks) == "table" then
            local stick = state.sticks[1] or state.sticks[0]
            if type(stick) == "table" then
                GI.HandleStick("Left", stick.x or 0, stick.y or 0)
            end
        end
    end
end

function GI.ReleaseAll()
    local profile = GI._profile
    if not profile then
        ResetHolds()
        return
    end
    local buttons = {}
    for btn, down in pairs(GI._held) do
        if down then
            buttons[#buttons + 1] = btn
        end
    end
    for i = 1, #buttons do
        GI.HandleButton(buttons[i], false)
    end
    if profile.onAxis then
        local E = Engine(profile.engine)
        if E then
            if profile.analog == "x" then
                profile.onAxis(E, 0)
            else
                profile.onAxis(E, 0, 0)
            end
        end
    end
    ResetHolds()
end

function GI.Start(gameId)
    GI.Stop()
    if not GI.IsEnabled() then return false end
    local profile = PROFILES[gameId]
    if not profile then return false end
    GI._activeGameId = gameId
    GI._profile = profile
    ResetHolds()
    local f = EnsureCaptureFrame()
    if f then
        f:Show()
        if f.EnableGamePadButton then f:EnableGamePadButton(true) end
        if f.EnableGamePadStick then f:EnableGamePadStick(true) end
    end
    local B = Bridge()
    if B and B.SetGameplayCapture then
        B.SetGameplayCapture(true, GI.HandleButton)
    end
    return true
end

function GI.Stop()
    GI.ReleaseAll()
    local B = Bridge()
    if B and B.SetGameplayCapture then
        B.SetGameplayCapture(false)
    end
    if GI._captureFrame then
        GI._captureFrame:Hide()
    end
    GI._activeGameId = nil
    GI._profile = nil
    GI._overlayMode = false
    GI._menuButtons = nil
    GI._overlayCancel = nil
    GI._overlayStack = {}
    ResetHolds()
end

function GI.OnBegin(gameId)
    if GI.HasProfile(gameId) then
        return GI.Start(gameId)
    end
    GI.Stop()
    return false
end

function GI.OnPause()
    GI.ReleaseAll()
    local B = Bridge()
    if B and B.SetGameplayCapture then
        B.SetGameplayCapture(false)
    end
    if GI._captureFrame then
        GI._captureFrame:Hide()
    end
end

function GI.OnResume(gameId)
    if GI._profile or GI.HasProfile(gameId) then
        return GI.Start(gameId or GI._activeGameId)
    end
    return false
end

function GI.InstallSessionHooks()
    local GS = ArcadiaNexus.GameSession
    if not GS or GI._hooksInstalled then return end
    GI._hooksInstalled = true

    local begin = GS.Begin
    function GS:Begin(gameId, opts)
        local sid = begin(self, gameId, opts)
        if sid then GI.OnBegin(gameId) end
        return sid
    end

    local pause = GS.Pause
    function GS:Pause(gameId, sessionId)
        local ok = pause(self, gameId, sessionId)
        if ok then GI.OnPause() end
        return ok
    end

    local resume = GS.Resume
    function GS:Resume(gameId, sessionId)
        local ok = resume(self, gameId, sessionId)
        if ok then GI.OnResume(gameId) end
        return ok
    end

    local ending = GS.End
    function GS:End(gameId, sessionId)
        local ok = ending(self, gameId, sessionId)
        if ok then GI.Stop() end
        return ok
    end

    local forceEnd = GS.ForceEnd
    function GS:ForceEnd(...)
        GI.Stop()
        return forceEnd(self, ...)
    end
end

function GI.Init()
    GI.InstallSessionHooks()
end
