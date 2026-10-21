-- Existing three saves stay in the original .saves path; no parallel persistence.
local A=_G.ArcadiaNexus
local S={MAX_SLOTS=3}; A.SOL_Settings=S
S.Defaults = {
    theme        = "neutral",
    mode         = "1card",
    soundEnabled = true,
    soundOnDeal  = true,
    soundOnPlace = true,
    soundOnFnd   = true,
    soundOnInval = true,
    soundOnWin   = true,
    soundOnUndo  = true,
}

local function DB() return A.Persistence:GetGameSettings("SOLITAIRE") end
function S:Get(key)
    local E=A.SOL_Engine
    if key=="mode" and E and E.gameState then return E.gameState.mode end
    local db=DB(); if db[key]~=nil then return db[key] end; return self.Defaults[key]
end
function S:Set(key,value)
    if self.Defaults[key]==nil then return false end
    if key=="mode" then return A.SOL_Engine:SetMode(value) end
    A.Persistence:SetGameSetting("SOLITAIRE",key,value); return true
end
function S:_SetMode(mode) A.Persistence:SetGameSetting("SOLITAIRE","mode",mode) end
function S:Reset()
    local db=DB(); for key in pairs(self.Defaults) do
        if key~="mode" or not (A.SOL_Engine and A.SOL_Engine.gameState) then db[key]=nil end
    end
end
function S:GetAll() local out={}; for key in pairs(self.Defaults) do out[key]=self:Get(key) end; return out end
local function Slot(slot) return type(slot)=="number" and slot==math.floor(slot) and slot>=1 and slot<=3 end
function S:EnsureSaves()
    local db=DB(); db.saves=db.saves or {}; if not Slot(db.activeSlot) then db.activeSlot=1 end
    if not db.saves[1] and db.savedMode then
        db.saves[1]={mode=db.savedMode,score=db.savedScore,elapsed=db.savedElapsed,midGame={
            mode=db.savedMode,stock=db.savedStock,waste=db.savedWaste,foundation=db.savedFoundation,
            tableau=db.savedTableau,score=db.savedScore,elapsed=db.savedElapsed,wastePass=db.savedWastePass}}
        for _,key in ipairs({"savedMode","savedStock","savedWaste","savedFoundation","savedTableau","savedScore","savedElapsed","savedWastePass","savedUndoCount"}) do db[key]=nil end
    end
    for slot=1,3 do
        local save=db.saves[slot]; local mid=type(save)=="table" and save.midGame
        if type(mid)=="table" and mid.saveVersion==nil and A.SOL_Logic:ValidateBoard(mid) and A.SOL_Logic:IsMode(mid.mode) then
            local score,elapsed,passes=mid.score or 0,mid.elapsed or 0,mid.wastePass or 0
            if type(score)=="number" and score>=0 and score==math.floor(score) and score<=2147483647
                and type(elapsed)=="number" and elapsed>=0 and elapsed*1000<=2147483647
                and type(passes)=="number" and passes>=0 and passes==math.floor(passes) then
                local gs=A.SOL_Logic:DeepCopy(mid)
                gs.saveVersion=2; gs.ruleVersion=2; gs.scoreVersion=1; gs.legacyScore=score
                gs.actionScore=score; gs.undoUsed=0; gs.undoStack={}; gs.undoCount=nil; gs.selected=nil
                gs.elapsedMs=math.floor(elapsed*1000+0.5); gs.wastePass=passes+1
                gs.phase=A.SOL_Logic:IsWin(gs) and "WIN" or "PLAYING"
                if gs.phase=="WIN" then gs.result="WIN"; gs.legacyCompleted=true end
                gs.runId=A.LocalResults:NewRun("SOLITAIRE"); A.SOL_Logic:Sync(gs)
                db.saves[slot]={mode=gs.mode,score=gs.score,elapsed=gs.elapsed,runId=gs.runId,midGame=gs,timestamp=save.timestamp or GetServerTime()}
            end
        end
    end
    return db.saves
end
function S:GetActiveSlot() self:EnsureSaves(); return DB().activeSlot end
function S:SetActiveSlot(slot) if not Slot(slot) then return false end; DB().activeSlot=slot; return true end
function S:LoadSlot(slot) slot=slot or self:GetActiveSlot(); if not Slot(slot) then return nil end; return self:EnsureSaves()[slot] end
function S:SaveSlot(slot,data)
    if not Slot(slot) then return false end
    self:EnsureSaves()[slot]=data; return true
end
function S:DeleteSlot(slot)
    local E=A.SOL_Engine; if not Slot(slot) or E.gameState and E.activeSlot==slot then return false end
    self:EnsureSaves()[slot]=nil; A.LocalResults:Prune(); return true
end
function S:SaveGame(gs)
    local slot=A.SOL_Engine.activeSlot or self:GetActiveSlot()
    return self:SaveSlot(slot,{mode=gs.mode,score=gs.score,elapsed=gs.elapsed,runId=gs.runId,
        midGame=A.SOL_Logic:DeepCopy(gs),timestamp=GetServerTime()})
end
function S:LoadGame(slot) local save=self:LoadSlot(slot); return save and A.SOL_Logic:DeepCopy(save.midGame) end
function S:HasSavedGame(slot) return A.SOL_Engine:CanContinueSave(self:LoadSlot(slot)) end
function S:_DeepCopy(value) return A.SOL_Logic:DeepCopy(value) end
