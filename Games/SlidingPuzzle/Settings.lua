-- ============================================================
--  SlidingPuzzle – Settings.lua
--  Persistente Einstellungen, Statistiken
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SLP_Settings = {}
local S = ArcadiaNexus.SLP_Settings

S.Defaults = {
    difficulty   = "easy",
    imageIndex   = 0,        -- 0 = Zufällig
    timerEnabled = true,
    soundEnabled = true,
    soundOnMove  = true,
    soundOnWin   = true,
}

local DB_KEY = "MOSAICOFAZEROTH"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

local function EnsureStats()
    local db = GetDB()
    if not db.stats then
        db.stats = {
            played  = { easy=0, medium=0, hard=0 },
            solved  = { easy=0, medium=0, hard=0 },
            bestMoves = { easy=0, medium=0, hard=0 },
            bestTime  = { easy=0, medium=0, hard=0 },
        }
    end
    -- Migrationsschutz: Fehlende Sub-Keys ergänzen
    local st = db.stats
    st.played    = st.played    or { easy=0, medium=0, hard=0 }
    st.solved    = st.solved    or { easy=0, medium=0, hard=0 }
    st.bestMoves = st.bestMoves or { easy=0, medium=0, hard=0 }
    st.bestTime  = st.bestTime  or { easy=0, medium=0, hard=0 }
    return st
end

-- ── Einstellungen ─────────────────────────────────────────────
function S:Get(key)
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, value) P:SetGameSetting(DB_KEY, key, value) end

function S:Reset()
    local db = GetDB()
    for k in pairs(self.Defaults) do db[k] = nil end
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do r[k] = self:Get(k) end
    return r
end

-- ── Statistiken ───────────────────────────────────────────────
function S:IncrementPlayed(diff)
    local st = EnsureStats()
    st.played[diff] = (st.played[diff] or 0) + 1
end

function S:IncrementSolved(diff)
    local st = EnsureStats()
    st.solved[diff] = (st.solved[diff] or 0) + 1
end

function S:GetSolvedCount(diff)
    return EnsureStats().solved[diff] or 0
end

function S:GetTotalSolved()
    local st = EnsureStats()
    return (st.solved.easy or 0) + (st.solved.medium or 0) + (st.solved.hard or 0)
end

function S:SubmitBest(diff, moves, time)
    local st = EnsureStats()
    local curM = st.bestMoves[diff] or 0
    local curT = st.bestTime[diff]  or 0
    if curM == 0 or moves < curM then
        st.bestMoves[diff] = moves
    end
    if curT == 0 or time < curT then
        st.bestTime[diff] = time
    end
end
