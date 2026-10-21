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
    showNumbers  = false,
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

function S:Set(key, value)
    local E=ArcadiaNexus.SLP_Engine
    if (key=="difficulty" or key=="imageIndex") and E and E:IsConfigLocked() then return false end
    if key=="difficulty" and not ArcadiaNexus.SLP_Logic.SIZES[value] then return false end
    if key=="imageIndex" and not ArcadiaNexus.SLP_Logic:Int(value,19) then return false end
    P:SetGameSetting(DB_KEY,key,value)
    if key=="showNumbers" and ArcadiaNexus.SLP_Renderer then ArcadiaNexus.SLP_Renderer:RefreshNumbers() end
    return true
end

function S:Reset()
    local db = GetDB()
    for k in pairs(self.Defaults) do
        local E=ArcadiaNexus.SLP_Engine
        if not ((k=="difficulty" or k=="imageIndex") and E and E:IsConfigLocked()) then db[k]=nil end
    end
    if ArcadiaNexus.SLP_Renderer then ArcadiaNexus.SLP_Renderer:RefreshNumbers() end
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

-- Modern saves/results are separate from all original size-dependent counters.
local function Modern()
    local db=GetDB()
    db.slots=db.slots or {}; db.modern=db.modern or {version=1,played={},solved={},puzzleBest={}}
    return db,db.modern
end
function S:LoadSlot(slot)
    if not ArcadiaNexus.SLP_Logic:Int(slot,3) or slot<1 then return nil end
    local db=Modern(); return db.slots[slot]
end
function S:SaveSlot(slot,snapshot) local db=Modern(); db.slots[slot]=ArcadiaNexus.SLP_Logic:Copy(snapshot) end
function S:DeleteSlot(slot) local db=Modern(); db.slots[slot]=nil end
function S:RecordStart(diff) local _,st=Modern(); st.played[diff]=(st.played[diff] or 0)+1 end
function S:GetModernSolved(diff) local _,st=Modern(); return st.solved[diff] or 0 end
function S:GetPuzzleBest(id) local _,st=Modern(); return st.puzzleBest[id] end
function S:GetLegacyBests(diff)
    local st=GetDB().stats
    st=type(st)=="table" and st or {}
    local moves=type(st.bestMoves)=="table" and st.bestMoves[diff] or 0
    local seconds=type(st.bestTime)=="table" and st.bestTime[diff] or 0
    return type(moves)=="number" and moves>=0 and moves or 0,
        type(seconds)=="number" and seconds>=0 and seconds or 0,({easy=3,medium=6,hard=8})[diff]
end
function S:QueueResult(data) local db=Modern(); db.pendingResults=db.pendingResults or {}; db.pendingResults[data.runId]=ArcadiaNexus.SLP_Logic:Copy(data) end
function S:GetPending(slot) local db=Modern(); for _,d in pairs(db.pendingResults or {}) do if type(d)=="table" and d.slot==slot then return d end end end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
function S:ValidateSnapshot(save,slot)
    local L,LR=ArcadiaNexus.SLP_Logic,ArcadiaNexus.LocalResults
    if type(save)~="table" or save.snapshotVersion~=1 or save.ruleVersion~=2 or save.ratingVersion~=1 or save.slot~=slot
        or not L:ValidPuzzle(save.puzzle) or not L:ValidBoard(save.board,save.puzzle.cols,save.emptyPos)
        or not L:Int(save.moves) or not L:Int(save.elapsedMs) or not L:Int(save.revision)
        or not LR:GetSerial(DB_KEY,save.runId) or LR:GetReceipt(save.runId) or not LR:GetJournal().issued[save.runId]
        or L:Model(save.board,save.puzzle.cols,save.emptyPos):IsSolved() then return nil end
    return L:Copy(save)
end
function S:ValidateResult(data,old)
    local L=ArcadiaNexus.SLP_Logic; local st=data.stats
    if data.result~="WIN" or data.score~=0 or data.skipHighscores~=true or data.ruleVersion~=2 or data.ratingVersion~=1
        or not L:Int(data.slot,3) or data.slot<1 or not L:ValidPuzzle(data.puzzle)
        or data.difficulty~="v2_"..data.puzzle.difficulty or type(st)~="table" or st.difficulty~=data.puzzle.difficulty
        or st.cols~=data.puzzle.cols or st.imageIndex~=data.puzzle.imageIndex or not L:Int(st.moves) or st.moves<1
        or not L:Int(st.elapsedMs) or st.time~=math.floor(st.elapsedMs/1000)
        or not L:ValidBoard(data.finalBoard,st.cols,st.cols*st.cols)
        or not L:Model(data.finalBoard,st.cols,st.cols*st.cols):IsSolved() then return false end
    local db=GetDB(); local frozen=old and old.mosaicFacts or (db.pendingResults or {})[data.runId]
    if not frozen then return false end
    for _,k in ipairs({"slot","ruleVersion","ratingVersion","puzzle","finalBoard","stats"}) do if not Same(data[k],frozen[k]) then return false end end
    return true
end
function S:ApplyResult(data)
    local db,st=Modern(); local diff=data.stats.difficulty
    st.solved[diff]=(st.solved[diff] or 0)+1
    local id=data.puzzle.puzzleId; local old=st.puzzleBest[id] or {}
    data.newMetricRecords={moves=not old.moves or data.stats.moves<old.moves,time=not old.elapsedMs or data.stats.elapsedMs<old.elapsedMs}
    st.puzzleBest[id]={ratingVersion=1,moves=math.min(old.moves or math.huge,data.stats.moves),elapsedMs=math.min(old.elapsedMs or math.huge,data.stats.elapsedMs)}
    db.slots[data.slot]={snapshotVersion=1,ruleVersion=2,ratingVersion=1,slot=data.slot,puzzle=ArcadiaNexus.SLP_Logic:Copy(data.puzzle),completed=true,timestamp=time()}
    db.pendingResults[data.runId]=nil
end
