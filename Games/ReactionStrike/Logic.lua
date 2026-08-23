-- Games/ReactionStrike/Logic.lua

ArcadiaNexus.RS_Logic = {}
local Logic = ArcadiaNexus.RS_Logic

-- ── Konfiguration pro Schwierigkeit ──────────────────────────
Logic.DiffConfig = {
    easy = {
        waitMin      = 1.5,
        waitMax      = 4.0,
        fakeoutChance= 0.0,
        fakeoutDur   = 0.0,
        moving       = false,
        orbSpeed     = 0,
        scoreFactor  = 1.0,
        penaltySec   = 1.0,
    },
    normal = {
        waitMin      = 1.0,
        waitMax      = 3.5,
        fakeoutChance= 0.25,
        fakeoutDur   = 0.8,
        moving       = true,
        orbSpeed     = 80,
        scoreFactor  = 1.5,
        penaltySec   = 1.5,
    },
    hard = {
        waitMin      = 0.5,
        waitMax      = 3.0,
        fakeoutChance= 0.40,
        fakeoutDur   = 0.5,
        moving       = true,
        orbSpeed     = 160,
        scoreFactor  = 2.0,
        penaltySec   = 2.0,
    },
}

-- Spielfeld-Dimensionen (vom Renderer gesetzt nach Init)
Logic.FIELD_W = 300
Logic.FIELD_H = 300
Logic.ORB_SIZE = 64

-- ── Neuer Versuch / State ─────────────────────────────────────
function Logic:NewState(difficulty)
    local cfg = self.DiffConfig[difficulty] or self.DiffConfig.normal
    return {
        difficulty   = difficulty,
        cfg          = cfg,
        -- Orb-Position (zentriert)
        orb = {
            x  = (self.FIELD_W - self.ORB_SIZE) / 2,
            y  = (self.FIELD_H - self.ORB_SIZE) / 2,
            vx = 0,
            vy = 0,
        },
        signalTime   = nil,
        reactionMs   = nil,
        score        = nil,
        penaltyType  = nil,
        penaltyAccum = 0,
    }
end

-- ── Wartezeit auswürfeln ──────────────────────────────────────
function Logic:RollWaitDelay(state)
    local cfg = state.cfg
    return cfg.waitMin + math.random() * (cfg.waitMax - cfg.waitMin)
end

-- ── Signal-Typ auswürfeln ─────────────────────────────────────
function Logic:RollSignalType(state)
    local cfg = state.cfg
    if math.random() < cfg.fakeoutChance then
        return "FAKEOUT"
    end
    return "SIGNAL"
end

-- ── Orb-Startgeschwindigkeit (Moving Target) ─────────────────
function Logic:RollOrbVelocity(state)
    local cfg   = state.cfg
    local speed = cfg.orbSpeed
    if speed <= 0 then
        state.orb.vx = 0
        state.orb.vy = 0
        return
    end
    -- Zufällige Richtung, keine Diagonale von exakt 0
    local angle = math.random() * 2 * math.pi
    state.orb.vx = math.cos(angle) * speed
    state.orb.vy = math.sin(angle) * speed
end

-- ── Orb-Position pro Tick updaten ────────────────────────────
function Logic:TickOrb(state, dt)
    local orb  = state.orb
    local maxX = self.FIELD_W - self.ORB_SIZE
    local maxY = self.FIELD_H - self.ORB_SIZE

    orb.x = orb.x + orb.vx * dt
    orb.y = orb.y + orb.vy * dt

    -- Wandabprall
    if orb.x < 0 then
        orb.x  = 0
        orb.vx = -orb.vx
    elseif orb.x > maxX then
        orb.x  = maxX
        orb.vx = -orb.vx
    end
    if orb.y < 0 then
        orb.y  = 0
        orb.vy = -orb.vy
    elseif orb.y > maxY then
        orb.y  = maxY
        orb.vy = -orb.vy
    end
end

-- ── Reaktionszeit messen ──────────────────────────────────────
function Logic:RecordStrike(state)
    if not state.signalTime then return 0 end
    local ms = math.floor((GetTime() - state.signalTime) * 1000)
    state.reactionMs = ms
    return ms
end

-- ── Score berechnen ───────────────────────────────────────────
function Logic:CalcScore(reactionMs, difficulty)
    local base    = math.max(0, math.floor(1000 - reactionMs))
    local factors = { easy = 1.0, normal = 1.5, hard = 2.0 }
    return math.floor(base * (factors[difficulty] or 1.0))
end

-- Näherungsweise Reaktionszeit aus gespeichertem Score (Anzeige)
function Logic:MsFromScore(score, difficulty)
    if not score or score <= 0 then return nil end
    local factors = { easy = 1.0, normal = 1.5, hard = 2.0 }
    local factor  = factors[difficulty] or 1.0
    return math.max(0, math.floor(1000 - (score / factor)))
end

-- ── Ergebnis-Label ───────────────────────────────────────────
function Logic:GetResultLabel(reactionMs)
    local L = ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")
    if reactionMs < 200 then
        return L["result_great"] or "Ausgezeichnet!", { 0.20, 1.00, 0.20 }
    elseif reactionMs < 350 then
        return L["result_good"] or "Gut!",            { 1.00, 0.84, 0.00 }
    elseif reactionMs < 500 then
        return L["result_ok"] or "Geht so.",           { 1.00, 0.65, 0.10 }
    else
        return L["result_slow"] or "Zu langsam!",      { 1.00, 0.30, 0.30 }
    end
end
