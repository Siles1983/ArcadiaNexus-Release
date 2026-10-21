-- Preferences and independent, complete table saves. Reset never refills capital.
local A=_G.ArcadiaNexus
local S={MAX_SLOTS=3}; A.HOL_Settings=S
S.Defaults={variant="standard",theme="neutral",soundEnabled=true,soundOnFlip=true,
    soundOnCorrect=true,soundOnWrong=true,soundOnCashout=true,soundOnJoker=true}
local function DB() return A.Persistence:GetGameSettings("HIGHERORLOWER") end
function S:Get(key)
    local E=A.HOL_Engine
    if key=="variant" and E and E.gameState then return E.gameState.variant end
    local db=DB(); if db[key]~=nil then return db[key] end
    return self.Defaults[key]
end
function S:Set(key,value)
    if self.Defaults[key]==nil then return false end
    if key=="variant" then return A.HOL_Engine:SetVariant(value) end
    A.Persistence:SetGameSetting("HIGHERORLOWER",key,value); return true
end
function S:_SetVariant(value) A.Persistence:SetGameSetting("HIGHERORLOWER","variant",value) end
function S:Reset()
    local db=DB()
    for k in pairs(self.Defaults) do if k~="variant" or not (A.HOL_Engine and A.HOL_Engine.gameState) then db[k]=nil end end
end
function S:GetAll() local out={}; for k in pairs(self.Defaults) do out[k]=self:Get(k) end; return out end
function S:EnsureMigration()
    local db=DB(); if db.tableMigration==2 then return end
    db.slots=db.slots or {}
    if type(db.chips)=="number" and db.chips>=0 and db.chips*2==math.floor(db.chips*2) and db.chips<=1073741823 then
        local slot; for i=1,3 do if not db.slots[i] then slot=i; break end end
        if not slot then return end
        local variant=db.difficulty=="hard" and "joker" or "standard"
        local gs=A.HOL_Logic:NewGameState(variant,db.chips)
        gs.runId=A.LocalResults:NewRun("HIGHERORLOWER"); gs.tableId=gs.runId; gs.legacyCapital=true
        if gs.chips2<50 then gs.phase="GAMEOVER" end
        db.slots[slot]=gs; db.variant=variant
    end
    db.chips=nil; db.bet=nil; db.difficulty=nil; db.tableMigration=2
end
function S:LoadSlot(slot) self:EnsureMigration(); return DB().slots[slot] end
function S:SaveSlot(slot,save)
    if type(slot)~="number" or slot~=math.floor(slot) or slot<1 or slot>3 then return false end
    local db=DB(); db.slots=db.slots or {}; db.slots[slot]=save; return true
end
function S:DeleteSlot(slot)
    local E=A.HOL_Engine; if E.gameState and E.activeSlot==slot then return false end
    local db=DB(); if db.slots then db.slots[slot]=nil end
    A.LocalResults:Prune(); return true
end
