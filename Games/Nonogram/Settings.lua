-- Games/Nonogram/Settings.lua

local ArcadiaNexus = _G.ArcadiaNexus
local S = {}
ArcadiaNexus.NON_Settings = S

S.Defaults = {
    difficulty   = "easy",
    defaultMode  = "free",
    soundEnabled = true,
    soundOnFill  = true,
    soundOnMark  = true,
    soundOnError = true,
    soundOnWin   = true,
    soundOnLose  = true,
}

local DB_KEY = "NONOGRAM"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return S.Defaults[key]
end

function S:Set(key, value)
    local E=ArcadiaNexus.NON_Engine
    if (key=="difficulty" or key=="defaultMode") and E and E:IsConfigLocked() then return false end
    if key=="difficulty" and not ArcadiaNexus.NON_Logic.DiffConfig[value] or key=="defaultMode" and value~="free" and value~="strict" then return false end
    P:SetGameSetting(DB_KEY,key,value); return true
end

function S:GetAll()
    return GetDB()
end

function S:Reset()
    local db = GetDB()
    for k, v in pairs(S.Defaults) do
        S:Set(k,v)
    end
end

-- ============================================================
-- STATISTIKEN
-- ============================================================
function S:GetStats()
    local db = GetDB()
    if not db.stats then
        db.stats = {
            played        = 0,
            wins          = 0,
            losses        = 0,
            puzzlesSolved = 0,
        }
    end
    return db.stats
end

function S:RecordResult(result)
    local stats = S:GetStats()
    stats.played = (stats.played or 0) + 1
    if result == "WIN" then
        stats.wins          = (stats.wins or 0) + 1
        stats.puzzlesSolved = (stats.puzzlesSolved or 0) + 1
    else
        stats.losses = (stats.losses or 0) + 1
    end
end

local A=ArcadiaNexus
local function Data()
    local db=GetDB(); db.slots=db.slots or {}; db.pendingResults=db.pendingResults or {}
    db.modern=db.modern or {version=2,played=0,wins=0,losses=0,best={}}
    return db,db.modern
end
function S:LoadSlot(slot) if not A.NON_Logic:Int(slot,3) or slot<1 then return nil end local db=Data(); return db.slots[slot] end
function S:ValidBags(bags)
    local L=A.NON_Logic; if type(bags)~="table" then return false end
    for diff,bag in pairs(bags) do
        if not L.DiffConfig[diff] or type(bag)~="table" or not L:Dense(bag.items,50,50) or not L:Int(bag.pos,51) or bag.pos<1 or not L:Int(bag.last,50) or bag.last<1 then return false end
        local seen={}; for _,i in ipairs(bag.items) do if i<1 or seen[i] then return false end seen[i]=true end
    end
    return true
end
function S:SaveSlot(slot,save) local db=Data(); db.slots[slot]=A.NON_Logic:Copy(save) end
function S:DeleteSlot(slot) if not self:GetPending(slot) then local db=Data(); db.slots[slot]=nil end end
function S:RecordStart() local _,st=Data(); st.played=st.played+1 end
function S:GetBest(id,mode) local _,st=Data(); return st.best[id..":"..mode] end
function S:GetPending(slot) local db=Data(); for _,d in pairs(db.pendingResults) do if type(d)=="table" and d.slot==slot then return d end end end
function S:QueueResult(data) local db=Data(); db.pendingResults[data.runId]=A.NON_Logic:Copy(data) end
function S:ValidateSnapshot(save,slot)
    local L=A.NON_Logic
    if type(save)~="table" or save.snapshotVersion~=1 or save.ruleVersion~=2 or save.catalogVersion~=2 or save.scoreVersion~=2
        or save.slot~=slot or not L:Int(save.revision) or not A.LocalResults:GetSerial("NONOGRAM",save.runId) or A.LocalResults:GetReceipt(save.runId) then return nil end
    local serial=A.LocalResults:GetSerial("NONOGRAM",save.runId)
    if A.LocalResults:GetJournal().issued[save.runId]~=serial or not self:ValidBags(save.bags) then return nil end
    local gs=L:ValidateState(save.gameState)
    if not gs or L:CheckWin(gs) or gs.mode=="strict" and gs.errors>=gs.errorLimit then return nil end
    local result=L:Copy(save); result.gameState=gs; return result
end
local function Facts(data)
    return {runId=data.runId,slot=data.slot,ruleVersion=data.ruleVersion,catalogVersion=data.catalogVersion,scoreVersion=data.scoreVersion,
        difficulty=data.difficulty,result=data.result,reason=data.reason,score=data.score,gameState=data.gameState,stats=data.stats}
end
function S:ValidateResult(data,old)
    local L=A.NON_Logic
    if data.ruleVersion~=2 or data.catalogVersion~=2 or data.scoreVersion~=2 or not L:Int(data.slot,3) or data.slot<1 then return false end
    local gs=L:ValidateState(data.gameState)
    if not gs or data.difficulty~=L:ScoreKey(gs.difficulty,gs.mode) or type(data.stats)~="table"
        or data.stats.difficulty~=gs.difficulty or data.stats.mode~=gs.mode or data.stats.elapsedMs~=gs.elapsedMs or data.stats.errors~=gs.errors then return false end
    if data.result=="WIN" then
        if not L:CheckWin(gs) or data.score~=L:CalcScore(gs) or data.reason~="solved" or gs.mode=="strict" and gs.errors>=gs.errorLimit then return false end
    elseif data.result=="LOSS" then
        if gs.mode~="strict" or gs.errors~=gs.errorLimit or data.reason~="errors" or data.score~=0 or L:CheckWin(gs) then return false end
    else return false end
    local frozen=old and old.nonFacts or self:GetPending(data.slot)
    return frozen and L:Same(Facts(frozen),Facts(data)) or false
end
function S:ApplyResult(data)
    local db,st=Data(); local gs=data.gameState
    st[data.result=="WIN" and "wins" or "losses"]=st[data.result=="WIN" and "wins" or "losses"]+1
    if data.result=="WIN" then
        local key=gs.puzzleId..":"..gs.mode; local old=st.best[key]
        data.newTimeRecord=not old or gs.elapsedMs<old.elapsedMs
        if data.newTimeRecord then st.best[key]={elapsedMs=gs.elapsedMs,scoreVersion=2} end
    end
    local previous=db.slots[data.slot]
    db.slots[data.slot]={snapshotVersion=1,ruleVersion=2,catalogVersion=2,scoreVersion=2,slot=data.slot,completed=true,
        gameState=A.NON_Logic:Copy(gs),bags=previous and A.NON_Logic:Copy(previous.bags) or {},timestamp=time()}
    db.pendingResults[data.runId]=nil
end
