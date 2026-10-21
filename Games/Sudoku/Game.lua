-- Durable Sudoku session. Rules and validation live in SDK_Logic.
local A=_G.ArcadiaNexus
local G={}; G.__index=G; A.SDK_Game=G
local function copy(v)
    if type(v)~="table" then return v end
    local t={}; for k,x in pairs(v) do t[k]=copy(x) end; return t
end
function G:New() return setmetatable({},self) end
function G:Init(config)
    self.logic=A.SDK_Logic
    local p=self.logic:GeneratePuzzle(config.difficulty,config.index)
    if not p then return false end
    self.grid,self.fixed,self.solution=p.grid,p.fixed,p.solution
    self.puzzleId,self.puzzleVersion=p.puzzleId,p.puzzleVersion
    self.difficulty=config.difficulty
    self.phase,self.moves,self.mistakes="PLAYING",0,0
    self.notes,self.history={},{}
    for r=1,9 do self.notes[r]={}; for c=1,9 do self.notes[r][c]={} end end
    self.notesMode=false
    self:Refresh(); return true
end
function G:Refresh(...) return self.logic:Refresh(self,...) end
function G:SelectCell(...) return self.logic:SelectCell(self,...) end
function G:Remember(...) return self.logic:Remember(self,...) end
function G:FinishEdit(...) return self.logic:FinishEdit(self,...) end
function G:PlaceNumber(...) return self.logic:PlaceNumber(self,...) end
function G:ClearCell(...) return self.logic:ClearCell(self,...) end
function G:Undo(...) return self.logic:Undo(self,...) end
function G:Snapshot()
    local t={version=1}
    for _,k in ipairs({"grid","fixed","solution","puzzleId","puzzleVersion","difficulty","phase","moves","mistakes","notes","history","runId","resultPending","notesMode","selected"}) do t[k]=copy(self[k]) end
    return t
end
function G:Load(save)
    if not A.SDK_Logic:ValidateSave(save) then return false end
    for k,v in pairs(copy(save)) do self[k]=v end
    self.logic=A.SDK_Logic; self:Refresh(); return true
end
function G:GetBoardState()
    return {grid=self.grid,fixed=self.fixed,errors=self.errors,notes=self.notes,notesMode=self.notesMode,
        phase=self.phase,selected=self.selected,highlightNum=self.highlightNum,moves=self.moves,mistakes=self.mistakes,
        difficulty=self.difficulty,score=self.logic:GetScore(self.difficulty),canUndo=#self.history>0 and self.phase=="PLAYING"}
end
