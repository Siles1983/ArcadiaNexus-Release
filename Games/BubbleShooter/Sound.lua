--[[
    ArcadiaNexus – Bubble Shooter
    Games/BubbleShooter/Sound.lua

    Kit-IDs. Schnelle Events (Schuss/Bounce) stoppen die laufende Instanz,
    sonst unterdrückt PlaySound denselben Kit bis er ausgelaufen ist.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BS_Sound = {}
local Sound = ArcadiaNexus.BS_Sound

local EVENTS = {
    start      = { key = "soundOnShoot",      id = 774  },
    shoot      = { key = "soundOnShoot",      id = 567,  restart = true },
    bounce     = { key = "soundOnShoot",      id = 1202, restart = true },
    pop        = { key = "soundOnPop",        id = 1489 },
    drop       = { key = "soundOnDrop",       id = 8959 },
    power      = { key = "soundOnPower",      id = 888  },
    overcharge = { key = "soundOnOvercharge", id = 8960 },
    win        = { key = "soundOnWin",        id = 8959 },
    lose       = { key = "soundOnLose",       id = 847  },
}

local handles = {}

local function StopHandle(handle)
    if not handle then return end
    if StopSound then
        pcall(StopSound, handle)
    end
end

function Sound.Stop()
    for event, handle in pairs(handles) do
        StopHandle(handle)
        handles[event] = nil
    end
end

function Sound.Play(event)
    local spec = EVENTS[event]
    if not spec then return end
    local S = ArcadiaNexus.BS_Settings
    if not S or not S:Get("soundEnabled") then return end
    if spec.key and S:Get(spec.key) == false then return end
    if spec.restart then
        StopHandle(handles[event])
        handles[event] = nil
    end
    -- 3. Arg forceNoDuplicates=false: gleicher Kit darf neu starten.
    local ok, a, b = pcall(PlaySound, spec.id, "SFX", false)
    if not ok then
        PlaySound(spec.id, "SFX")
        return
    end
    local handle = (type(b) == "number" and b) or (type(a) == "number" and a)
    if handle then
        handles[event] = handle
    end
end
