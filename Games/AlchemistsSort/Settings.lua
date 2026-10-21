-- ============================================================
--  AlchemistsSort – Settings.lua
--  Persistente Einstellungen, Statistiken, Level-Fortschritt
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ALS_Settings = {}
local S = ArcadiaNexus.ALS_Settings

S.Defaults = {
    soundEnabled    = true,
    soundOnPour     = true,
    soundOnWin      = true,
    soundOnInvalid  = true,
}

S.MAX_SLOTS = 3

local DB_KEY = "ALCHEMISTSSORT"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

local function NonNegativeInt(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return 0 end
    return math.max(0, math.floor(value))
end

-- Sort has no final level. Grow the normalization bound with the saved progress;
-- never use the currently selected replay level as the campaign's upper bound.
local function NormalizeCampaign(save)
    if type(save) ~= "table" then return nil end
    local CP = ArcadiaNexus.CampaignProgress
    local legacy = save.campaignVersion == nil
    local unlocked = math.max(1, NonNegativeInt(save.unlockedLevel),
        NonNegativeInt(save.currentLevel), NonNegativeInt(save.clearedLevel) + 1)
    if type(save.stars) == "table" then
        for level, stars in pairs(save.stars) do
            if NonNegativeInt(stars) > 0 then
                unlocked = math.max(unlocked, NonNegativeInt(level) + 1)
            end
        end
    end
    save.clearedLevel = math.max(NonNegativeInt(save.clearedLevel), unlocked - 1)
    CP.Normalize(save, { levelCount=unlocked, maxStars=3 })
    -- Legacy unlocks prove completion, but not how many aids were used.
    -- Grant only the completion star, once; global move/time records are not ratings.
    if legacy then
        for level = 1, save.clearedLevel do
            if CP.GetStars(save, level) == 0 then save.stars[level] = 1 end
        end
    end
    save.unlockedLevel = unlocked -- compatibility field for the existing slot UI
    return save
end

local function EnsureSaves(db)
    local hadSlots = type(db.saves) == "table"
    if not hadSlots then db.saves = {} end
    if not db.activeSlot then db.activeSlot = 1 end
    -- Nur Daten ohne Slot-Tabelle sind noch nicht migriert. Eine vorhandene,
    -- leere Tabelle kann einen bewusst gelöschten ersten Slot bedeuten.
    if not hadSlots and (db.currentLevel or db.unlockedLevel) then
        db.saves[1] = {
            currentLevel  = db.currentLevel or 1,
            unlockedLevel = db.unlockedLevel or db.currentLevel or 1,
        }
    end
    db.currentLevel = nil
    db.unlockedLevel = nil
    return db.saves
end

local function EnsureSlot(db, slot)
    local saves = EnsureSaves(db)
    if not saves[slot] then
        saves[slot] = { currentLevel = 1, unlockedLevel = 1 }
    end
    return NormalizeCampaign(saves[slot])
end

local function EnsureStats()
    local db = GetDB()
    if not db.stats then
        db.stats = { played = 0, solved = 0, topScores = { 0, 0, 0 } }
    end
    return db.stats
end

local function EnsureLevelBest()
    local db = GetDB()
    if not db.levelBest then db.levelBest = {} end
    return db.levelBest
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

-- ── Save-Slots ────────────────────────────────────────────────
function S:GetActiveSlot()
    local db = GetDB()
    EnsureSaves(db)
    return db.activeSlot or 1
end

function S:SetActiveSlot(slot)
    local db = GetDB()
    EnsureSaves(db)
    slot = tonumber(slot) or 1
    if slot >= 1 and slot <= S.MAX_SLOTS then
        db.activeSlot = slot
    end
end

function S:LoadSlot(slot)
    slot = tonumber(slot) or self:GetActiveSlot()
    if slot < 1 or slot > S.MAX_SLOTS then return nil end
    local db = GetDB()
    EnsureSaves(db)
    return NormalizeCampaign(db.saves[slot])
end

function S:SaveMidGame(slot, midGame)
    local db = GetDB()
    local save = EnsureSlot(db, slot)
    save.midGame   = midGame
    save.runId    = type(midGame)=="table" and midGame.runId or nil
    save.timestamp = time()
end

function S:ClearMidGame(slot)
    local save = self:LoadSlot(slot)
    if save then save.midGame = nil; save.runId=nil end
end

function S:ClearPending(slot)
    local pending = GetDB().pendingResults
    if type(pending) ~= "table" then return end
    for runId, data in pairs(pending) do
        if type(data) == "table" and data.slot == slot then pending[runId] = nil end
    end
end

function S:ClearPuzzle(slot, level)
    local save = self:LoadSlot(slot)
    if save and type(save.puzzles) == "table" then save.puzzles[level] = nil end
end

function S:DeleteSlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    EnsureSaves(db)
    db.saves[slot] = nil
    self:ClearPending(slot)
end

function S:ResetSlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    local save = EnsureSlot(db, slot)
    ArcadiaNexus.CampaignProgress.Reset(save)
    save.unlockedLevel = 1
    save.midGame       = nil
    save.runId         = nil
    save.puzzles       = nil
    save.timestamp     = time()
    self:ClearPending(slot)
end

-- ── Level-Fortschritt (pro aktivem Slot) ──────────────────────
function S:GetCurrentLevel()
    local save = self:LoadSlot(self:GetActiveSlot())
    return (save and save.currentLevel) or 1
end

function S:SetCurrentLevel(lvl)
    local db = GetDB()
    local save = EnsureSlot(db, self:GetActiveSlot())
    save.currentLevel = math.max(1, math.min(save.unlockedLevel, NonNegativeInt(lvl)))
end

function S:GetUnlockedLevel()
    local save = self:LoadSlot(self:GetActiveSlot())
    return (save and save.unlockedLevel) or 1
end

function S:IsLevelUnlocked(level)
    local save = self:LoadSlot(self:GetActiveSlot())
    if not save or type(level) ~= "number" or level ~= math.floor(level)
        or level < 1 or level > save.unlockedLevel then return false end
    return ArcadiaNexus.CampaignProgress.IsLevelUnlocked(save, level,
        { levelCount=save.unlockedLevel, maxStars=3 })
end

function S:GetStar(save, level)
    return ArcadiaNexus.CampaignProgress.GetStars(save, level)
end

function S:SumStars(save)
    return ArcadiaNexus.CampaignProgress.TotalStars(save)
end

function S:RecordLevel(level, stars)
    if not self:IsLevelUnlocked(level) or type(stars) ~= "number"
        or stars ~= math.floor(stars) or stars < 1 or stars > 3 then return 0, false, 0 end
    local save = self:LoadSlot(self:GetActiveSlot())
    local best, improved, gained = ArcadiaNexus.CampaignProgress.RecordLevel(save, level, stars,
        { levelCount=math.max(save.unlockedLevel, level + 1), maxStars=3 })
    save.unlockedLevel = math.max(save.unlockedLevel, save.clearedLevel + 1)
    save.timestamp = time()
    return best, improved, gained
end

-- ── Statistiken ───────────────────────────────────────────────
function S:IncrementPlayed()
    local st = EnsureStats()
    st.played = (st.played or 0) + 1
end

function S:IncrementSolved()
    local st = EnsureStats()
    st.solved = (st.solved or 0) + 1
end

function S:GetStat(key)
    return EnsureStats()[key] or 0
end

-- Top-3 Score aktualisieren
function S:SubmitScore(score)
    local st = EnsureStats()
    local top = st.topScores or { 0, 0, 0 }
    table.insert(top, score)
    table.sort(top, function(a, b) return a > b end)
    while #top > 3 do table.remove(top) end
    st.topScores = top
end

-- ── Level-Bestleistungen ──────────────────────────────────────
function S:GetLevelBest(levelId)
    return EnsureLevelBest()[levelId]
end

function S:SubmitLevelBest(levelId, moves, time)
    local lb = EnsureLevelBest()
    local cur = lb[levelId]
    if not cur then
        lb[levelId] = { moves = moves, time = time }
    else
        if moves < (cur.moves or math.huge) then cur.moves = moves end
        if time  < (cur.time  or math.huge) then cur.time  = time  end
    end
end

-- ── Streak-Tracking (Session, nicht persistent) ───────────────
S._sessionStreak = 0

function S:GetSessionStreak() return S._sessionStreak end

function S:IncrementStreak()
    S._sessionStreak = S._sessionStreak + 1
end

function S:ResetStreak()
    S._sessionStreak = 0
end

-- M7 keeps historical levelBest/topScores untouched; modern metrics have their own keys.
function S:GetPuzzle(slot, level)
    local save=self:LoadSlot(slot)
    return save and save.puzzles and save.puzzles[level]
end
function S:ReservePuzzle(slot, level, puzzle)
    local save=EnsureSlot(GetDB(),slot); save.puzzles=save.puzzles or {}
    if not save.puzzles[level] then save.puzzles[level]=ArcadiaNexus.ALS_Logic:Copy(puzzle) end
    return save.puzzles[level]
end
function S:GetPuzzleBest(puzzleId, aid)
    local db=GetDB(); local keys=db.puzzleBest or {}
    return keys[puzzleId] and keys[puzzleId][aid]
end
function S:GetLevelBests(level)
    local puzzle=self:GetPuzzle(self:GetActiveSlot(),level)
    local out={}
    if puzzle then for _,aid in ipairs({"unassisted","hint_or_undo","extra_bottle"}) do
        out[aid]=self:GetPuzzleBest(puzzle.puzzleId,aid)
    end end
    return out,self:GetLevelBest(level)
end
function S:QueueResult(data)
    local db=GetDB(); db.pendingResults=db.pendingResults or {}
    db.pendingResults[data.runId]=ArcadiaNexus.ALS_Logic:Copy(data)
end
function S:GetPending(slot)
    for _,data in pairs(GetDB().pendingResults or {}) do if data.slot==slot then return data end end
end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
function S:ValidateResult(data, old)
    local L=ArcadiaNexus.ALS_Logic; local st=data.stats
    if data.ruleVersion~=2 or data.ratingVersion~=1 or data.result~="WIN" or data.score~=0
        or data.skipHighscores~=true or data.difficulty~="normal" or not L:Int(data.slot,3) or data.slot<1
        or not L:Int(data.level) or data.level<1 or type(st)~="table"
        or not L:Int(st.moves) or not L:Int(st.elapsedMs) or not L:Int(st.stars,3) or st.stars<1
        or st.level~=data.level or st.levelReached~=data.level or st.time~=math.floor(st.elapsedMs/1000)
        or type(st.usedUndo)~="boolean" or type(st.usedHint)~="boolean" or type(st.usedAddTube)~="boolean"
        or data.aidClass~=L:AidClass(st) or st.stars~=(st.usedAddTube and 1 or (st.usedHint or st.usedUndo) and 2 or 3)
        or type(data.puzzleId)~="string" or not L:Int(st.streak) then return false end
    local p=self:GetPuzzle(data.slot,data.level)
    if not p or p.puzzleId~=data.puzzleId or not L:ValidateBoard(data.finalTubes,p.colors,p.baseTubes+(st.usedAddTube and 1 or 0))
        or not L:CheckWin(data.finalTubes) or not Same(data.minimum,p.minimum) then return false end
    if st.minimumExact~=(data.minimum.kind=="exact" and not st.usedAddTube)
        or st.minMoves~=(st.minimumExact and data.minimum.moves or 0) then return false end
    local frozen=old and old.alsFacts or (GetDB().pendingResults or {})[data.runId]
    if not frozen then return false end
    for _,k in ipairs({"slot","level","puzzleId","ruleVersion","ratingVersion","aidClass","minimum","finalTubes","stats"}) do
        if not Same(frozen[k],data[k]) then return false end
    end
    return true
end
function S:ApplyResult(data)
    local L=ArcadiaNexus.ALS_Logic; local db=GetDB(); local save=EnsureSlot(db,data.slot)
    local best,improved,gained=ArcadiaNexus.CampaignProgress.RecordLevel(save,data.level,data.stats.stars,
        {levelCount=math.max(save.unlockedLevel,data.level+1),maxStars=3})
    save.unlockedLevel=math.max(save.unlockedLevel,save.clearedLevel+1)
    save.currentLevel=math.min(save.unlockedLevel,data.level+1); save.midGame=nil; save.runId=nil; save.timestamp=time()
    db.puzzleBest=db.puzzleBest or {}; db.puzzleBest[data.puzzleId]=db.puzzleBest[data.puzzleId] or {}
    local byAid=db.puzzleBest[data.puzzleId]; local prev=byAid[data.aidClass] or {}
    data.newMetricRecords={moves=not prev.moves or data.stats.moves<prev.moves,time=not prev.elapsedMs or data.stats.elapsedMs<prev.elapsedMs}
    byAid[data.aidClass]={moves=math.min(prev.moves or math.huge,data.stats.moves),
        elapsedMs=math.min(prev.elapsedMs or math.huge,data.stats.elapsedMs),ratingVersion=1}
    data.bestStars,data.starsImproved,data.starsGained=best,improved,gained
    self:IncrementSolved()
    if db.pendingResults then db.pendingResults[data.runId]=nil end
end

-- Migrate only a validated copy. Never replace the caller's legacy object on failure.
function S:PrepareSnapshot(mid, slot, level)
    local L,G=ArcadiaNexus.ALS_Logic,ArcadiaNexus.ALS_LevelGen
    if type(mid)~="table" or mid.snapshotVersion and mid.snapshotVersion~=2 then return nil end
    local m=L:Copy(mid); local legacy=m.snapshotVersion==nil
    if not L:Int(level) or level<1 then return nil end
    -- An existing board keeps its own color count. Catalog bands apply only to a new level.
    local stored=type(m.initTubes)=="table" and #m.initTubes or 0
    local colors,base
    if stored>=5 and stored<=10 then colors,base=stored-2,stored
    else colors=ArcadiaNexus.ALS_Colors:GetColorCount(level); base=colors+2 end
    if not L:Int(level) or level<1 or not self:IsLevelUnlocked(level) then return nil end
    if legacy then
        -- Reject malformed legacy fields before arithmetic, copying or serialization.
        if not L:ValidateBoard(m.initTubes,colors,base) or L:CheckWin(m.initTubes)
            or type(m.tubes)~="table" or not L:ValidateBoard(m.tubes,colors,#m.tubes)
            or m.undosLeft~=nil and not L:Int(m.undosLeft,3)
            or m.hintsLeft~=nil and not L:Int(m.hintsLeft,3)
            or m.moveCount~=nil and not L:Int(m.moveCount)
            or m.elapsed~=nil and (type(m.elapsed)~="number" or m.elapsed~=m.elapsed or m.elapsed<0 or m.elapsed>=math.huge)
            or not L:IsDense(m.undoStack or {},3) then return nil end
        for _,key in ipairs({"usedUndo","usedHint","addedTube","usedAddTube"}) do
            if m[key]~=nil and type(m[key])~="boolean" then return nil end
        end
        for _,board in ipairs(m.undoStack or {}) do
            if type(board)~="table" or not L:ValidateBoard(board,colors,#board) then return nil end
        end
        m.slot,m.level,m.ruleVersion,m.ratingVersion,m.snapshotVersion=slot,level,2,1,2
        m.baseTubes=base; m.revision=0
        m.undosLeft=m.undosLeft or 0; m.hintsLeft=m.hintsLeft or 0
        m.usedUndo=m.usedUndo==true or m.undosLeft<3; m.usedHint=m.usedHint==true or m.hintsLeft<3
        m.addedTube=m.addedTube==true or m.usedAddTube==true; m.usedAddTube=m.addedTube
        local count=base+(m.addedTube and 1 or 0)
        if type(m.tubes)=="table" and #m.tubes==base and m.addedTube then m.tubes[count]={} end
        m.numTubes=count
        m.puzzle=G:MakePuzzle(m.initTubes or {},{}, {kind="unknown"},"legacy")
        m.moveCount=m.moveCount or 0; m.elapsed=m.elapsed or 0
        if not L:IsDense(m.undoStack or {},3) then return nil end
        local stack={}
        for _,b in ipairs(m.undoStack or {}) do
            if L:BoardKey(b)==L:BoardKey(m.tubes or {}) then return nil end -- old mid-pour divergence
            stack[#stack+1]={tubes=L:DeepCopy(b),moves=math.max(0,m.moveCount-#(m.undoStack or {})+#stack)}
        end
        m.undoStack=stack
    end
    if m.slot~=slot or m.level~=level or m.ruleVersion~=2 or m.ratingVersion~=1
        or m.baseTubes~=base or m.numTubes~=base+(m.addedTube and 1 or 0)
        or type(m.addedTube)~="boolean" or m.usedAddTube~=m.addedTube
        or type(m.usedUndo)~="boolean" or type(m.usedHint)~="boolean"
        or not L:Int(m.undosLeft,3) or not L:Int(m.hintsLeft,3)
        or m.undosLeft<3 and not m.usedUndo or m.hintsLeft<3 and not m.usedHint
        or not L:Int(m.moveCount) or not L:Int(m.revision)
        or type(m.elapsed)~="number" or m.elapsed~=m.elapsed or m.elapsed<0 or m.elapsed>=math.huge
        or not L:ValidateBoard(m.tubes,colors,m.numTubes) or not L:ValidateBoard(m.initTubes,colors,base)
        or L:CheckWin(m.tubes) or type(m.puzzle)~="table" or m.puzzle.puzzleId~=L:PuzzleId(m.initTubes)
        or m.puzzle.colors~=colors or m.puzzle.ruleVersion~=2 or m.puzzle.baseTubes~=base
        or not L:ValidateBoard(m.puzzle.initialTubes,colors,base)
        or L:BoardKey(m.puzzle.initialTubes)~=L:BoardKey(m.initTubes)
        or type(m.puzzle.minimum)~="table" then return nil end
    if not G:VerifyPuzzle(m.puzzle) then return nil end
    local reserved=self:GetPuzzle(slot,level)
    if reserved and not Same(reserved,m.puzzle) then return nil end
    if not L:IsDense(m.undoStack,3) then return nil end
    for _,u in ipairs(m.undoStack) do
        if type(u)~="table" or type(u.tubes)~="table" or not L:Int(u.moves) or u.moves>=m.moveCount
            or not L:ValidateBoard(u.tubes,colors,#u.tubes) or (#u.tubes~=base and #u.tubes~=m.numTubes) then return nil end
    end
    if not legacy and (type(m.runId)~="string" or not ArcadiaNexus.LocalResults:GetSerial("ALCHEMISTSSORT",m.runId)) then return nil end
    return m,legacy
end
function S:AdoptSnapshot(m, legacy)
    local save=EnsureSlot(GetDB(),m.slot)
    if legacy then save.legacySnapshots=save.legacySnapshots or {}; save.legacySnapshots[#save.legacySnapshots+1]=save.midGame end
    if not m.runId then m.runId=ArcadiaNexus.LocalResults:NewRun("ALCHEMISTSSORT") end
    self:ReservePuzzle(m.slot,m.level,m.puzzle)
    self:SaveMidGame(m.slot,ArcadiaNexus.ALS_Logic:Copy(m))
    return m
end
