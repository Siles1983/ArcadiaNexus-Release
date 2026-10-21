-- Klondike rules, shared move execution and durable 20-action undo history.
local A=_G.ArcadiaNexus
local L={}; A.SOL_Logic=L
local SUITS={"herz","karo","kreuz","pik"}
local RANKS={"A","2","3","4","5","6","7","8","9","10","J","Q","K"}
local KEYS={"C","D","H","S"}
local VALUES={}; for i,r in ipairs(RANKS) do VALUES[r]=i end
L.SCORE={WASTE_TO_TABLEAU=5,WASTE_TO_FOUND=10,TABLEAU_TO_FOUND=10,FLIP_CARD=5,FOUND_TO_TABLEAU=-15,UNDO_PENALTY=-15,WASTE_PASS_PENALTY=-20}
-- Confirmed: flat 20-point recycle penalty from pass 4 in draw-three mode.
L.RECYCLE_POLICY="flat"
function L:DeepCopy(v)
    if type(v)~="table" then return v end
    local out={}; for k,x in pairs(v) do out[k]=self:DeepCopy(x) end; return out
end
function L:IsMode(mode) return mode=="1card" or mode=="3card" end
function L:IsRed(card) return card and (card.suit=="herz" or card.suit=="karo") or false end
function L:IsBlack(card) return card and (card.suit=="kreuz" or card.suit=="pik") or false end
function L:RankValue(card) return card and VALUES[card.rank] or 0 end
function L:SuitKey(suit) return ({herz="H",karo="D",kreuz="C",pik="S"})[suit] end
function L:NewDeck()
    local deck={}; for _,s in ipairs(SUITS) do for _,r in ipairs(RANKS) do deck[#deck+1]={suit=s,rank=r,faceUp=false} end end
    return A.ArrayUtils.Shuffle(deck)
end
function L:Sync(gs) gs.score=math.max(0,gs.actionScore-15*gs.undoUsed); gs.elapsed=gs.elapsedMs/1000 end
function L:NewGameState(mode)
    local deck=self:NewDeck()
    local gs={mode=mode or "1card",stock={},waste={},foundation={C={},D={},H={},S={}},tableau={{},{},{},{},{},{},{}},
        actionScore=0,undoUsed=0,elapsedMs=0,wastePass=1,undoStack={},phase="PLAYING",saveVersion=2,ruleVersion=2,scoreVersion=2}
    for col=1,7 do for row=1,col do
        local card=table.remove(deck); card.faceUp=row==col; gs.tableau[col][row]=card
    end end
    gs.stock=deck; self:Sync(gs); return gs
end
function L:CanPlaceOnTableau(card,top)
    if not card or not card.faceUp then return false end
    if not top then return card.rank=="K" end
    return top.faceUp and self:IsRed(card)~=self:IsRed(top) and self:RankValue(top)-self:RankValue(card)==1
end
function L:CanPlaceOnFoundation(card,pile)
    if not card or not card.faceUp or type(pile)~="table" then return false end
    if #pile==0 then return card.rank=="A" end
    local top=pile[#pile]; return card.suit==top.suit and self:RankValue(card)==#pile+1
end
function L:FindFoundationKey(gs,card)
    for _,key in ipairs(KEYS) do if self:CanPlaceOnFoundation(card,gs.foundation[key]) then return key end end
end
local function Key(index) return type(index)=="number" and KEYS[index] or index end
function L:GetSelectedCards(gs,zone,index,cardIndex)
    local pile,start
    if zone=="waste" then
        pile=gs.waste; if index~=#pile or cardIndex and cardIndex~=#pile then return nil end; start=#pile
    elseif zone=="foundation" then
        pile=gs.foundation[Key(index)]; if not pile or cardIndex and cardIndex~=#pile then return nil end; start=#pile
    elseif zone=="tableau" then pile=gs.tableau[index]; start=cardIndex or (pile and #pile)
    else return nil end
    if not pile or type(start)~="number" or start~=math.floor(start) or start<1 or start>#pile then return nil end
    local cards={}
    for i=start,#pile do
        local card=pile[i]; if not card.faceUp then return nil end
        if i>start and not self:CanPlaceOnTableau(card,pile[i-1]) then return nil end
        cards[#cards+1]=card
    end
    return cards,start,pile
end
function L:IsSelectable(gs,zone,index,cardIndex) return self:GetSelectedCards(gs,zone,index,cardIndex)~=nil end
function L:CanMove(gs,src,dst)
    if type(src)~="table" or type(dst)~="table" then return false end
    local cards,start,pile=self:GetSelectedCards(gs,src.zone,src.index,src.cardIndex)
    if not cards then return false end
    local target
    if dst.zone=="foundation" then
        if src.zone=="foundation" or #cards~=1 then return false end
        target=gs.foundation[Key(dst.index)]
        if not self:CanPlaceOnFoundation(cards[1],target) then return false end
    elseif dst.zone=="tableau" then
        target=gs.tableau[dst.index]
        if not target or target==pile or not self:CanPlaceOnTableau(cards[1],target[#target]) then return false end
    else return false end
    return true,cards,start,pile,target
end
function L:SnapshotState(gs)
    return {stock=self:DeepCopy(gs.stock),waste=self:DeepCopy(gs.waste),foundation=self:DeepCopy(gs.foundation),
        tableau=self:DeepCopy(gs.tableau),actionScore=gs.actionScore,wastePass=gs.wastePass}
end
function L:PushUndo(gs)
    if #gs.undoStack>=20 then table.remove(gs.undoStack,1) end
    gs.undoStack[#gs.undoStack+1]=self:SnapshotState(gs)
end
function L:TryMove(gs,src,dst,simulation)
    local ok,cards,start,pile,target=self:CanMove(gs,src,dst); if not ok then return false end
    if not simulation then self:PushUndo(gs) end
    for i=1,#cards do table.remove(pile,start) end
    for _,card in ipairs(cards) do target[#target+1]=card end
    local flipped=false
    if src.zone=="tableau" and pile[#pile] and not pile[#pile].faceUp then pile[#pile].faceUp=true; flipped=true end
    local delta=dst.zone=="foundation" and 10 or (src.zone=="waste" and 5 or src.zone=="foundation" and -15 or 0)
    if flipped then delta=delta+5 end
    gs.actionScore=math.max(0,gs.actionScore+delta); gs.selected=nil; self:Sync(gs)
    return true,delta
end
function L:TryMoveToFoundation(gs,zone,index,cardIndex)
    local cards=self:GetSelectedCards(gs,zone,index,cardIndex)
    if not cards or #cards~=1 then return false end
    local key=self:FindFoundationKey(gs,cards[1]); if not key then return false end
    return self:TryMove(gs,{zone=zone,index=index,cardIndex=cardIndex},{zone="foundation",index=key})
end
function L:TryMoveToTableau(gs,zone,index,cardIndex)
    for pass=1,2 do for col=1,7 do
        if (#gs.tableau[col]>0)==(pass==1) then
            local ok,delta=self:TryMove(gs,{zone=zone,index=index,cardIndex=cardIndex},{zone="tableau",index=col})
            if ok then return true,delta end
        end
    end end
    return false
end
function L:DrawFromStock(gs)
    if #gs.stock==0 and #gs.waste==0 then return false end
    self:PushUndo(gs); gs.selected=nil
    if #gs.stock==0 then
        gs.wastePass=gs.wastePass+1
        if gs.mode=="3card" and gs.wastePass>=4 then
            local penalty=20
            gs.actionScore=math.max(0,gs.actionScore-penalty)
        end
        for i=#gs.waste,1,-1 do local card=table.remove(gs.waste); card.faceUp=false; gs.stock[#gs.stock+1]=card end
        self:Sync(gs); return true,"recycle"
    end
    for i=1,(gs.mode=="3card" and 3 or 1) do
        local card=table.remove(gs.stock); if not card then break end
        card.faceUp=true; gs.waste[#gs.waste+1]=card
    end
    self:Sync(gs); return true,"draw"
end
function L:RestoreSnapshot(gs,snapshot)
    for _,key in ipairs({"stock","waste","foundation","tableau","actionScore","wastePass"}) do gs[key]=self:DeepCopy(snapshot[key]) end
    gs.selected=nil; self:Sync(gs)
end
function L:Undo(gs)
    if #gs.undoStack==0 then return false end
    local snap=table.remove(gs.undoStack); gs.undoUsed=gs.undoUsed+1; self:RestoreSnapshot(gs,snap); return true
end
function L:IsWin(gs)
    for _,key in ipairs(KEYS) do if #gs.foundation[key]~=13 then return false end end
    return #gs.stock==0 and #gs.waste==0
end
function L:GetSources(gs)
    local sources={}
    if #gs.waste>0 then sources[#sources+1]={zone="waste",index=#gs.waste} end
    for i=1,4 do if #gs.foundation[KEYS[i]]>0 then sources[#sources+1]={zone="foundation",index=i} end end
    for i=1,7 do for j=1,#gs.tableau[i] do if gs.tableau[i][j].faceUp then sources[#sources+1]={zone="tableau",index=i,cardIndex=j} end end end
    return sources
end
function L:HasValidMoves(gs)
    if #gs.stock>0 or #gs.waste>0 then return true end -- draw or unlimited recycle
    for _,src in ipairs(self:GetSources(gs)) do
        for i=1,7 do if self:CanMove(gs,src,{zone="tableau",index=i}) then return true end end
        for i=1,4 do if self:CanMove(gs,src,{zone="foundation",index=i}) then return true end end
    end
    return false -- advisory only; never a proof of defeat
end
function L:AutoBuildMoveQueue(gs)
    if #gs.stock>0 or #gs.waste>0 then return nil end
    for i=1,7 do for _,card in ipairs(gs.tableau[i]) do if not card.faceUp then return nil end end end
    local sim=self:DeepCopy(gs); local queue={}
    for step=1,52 do
        if self:IsWin(sim) then return queue end
        local moved=false
        for col=1,7 do
            local pile=sim.tableau[col]; local card=pile[#pile]
            if card then
                local key=self:FindFoundationKey(sim,card)
                if key then
                    local src={zone="tableau",index=col,cardIndex=#pile}; local dst={zone="foundation",index=key}
                    if not self:TryMove(sim,src,dst,true) then return nil end
                    queue[#queue+1]={src=src,dst=dst,rank=card.rank,suit=card.suit}; moved=true; break
                end
            end
        end
        if not moved then return nil end
    end
    return self:IsWin(sim) and queue or nil
end
function L:CanAutoComplete(gs) local queue=self:AutoBuildMoveQueue(gs); return queue~=nil and #queue>0 end
local function Int(n,max) return type(n)=="number" and n==math.floor(n) and n>=0 and n<=(max or 2147483647) end
local function Array(value, max)
    if type(value)~="table" or #value>(max or 52) then return false end
    local n=#value; local count=0
    for key in pairs(value) do
        if type(key)~="number" or key~=math.floor(key) or key<1 or key>n then return false end
        count=count+1
    end
    return count==n
end
function L:ValidateBoard(gs)
    if type(gs)~="table" or not Array(gs.stock) or not Array(gs.waste) or type(gs.foundation)~="table" or not Array(gs.tableau,7) or #gs.tableau~=7 then return false end
    for key in pairs(gs.foundation) do if key~="C" and key~="D" and key~="H" and key~="S" then return false end end
    local seen,total={},0
    local function Card(card,up)
        if type(card)~="table" or not VALUES[card.rank] or not L:SuitKey(card.suit) or type(card.faceUp)~="boolean" or up~=nil and card.faceUp~=up then return false end
        local key=card.suit..card.rank; if seen[key] then return false end
        seen[key]=true; total=total+1; return true
    end
    for _,card in ipairs(gs.stock) do if not Card(card,false) then return false end end
    for _,card in ipairs(gs.waste) do if not Card(card,true) then return false end end
    local suits={}
    for _,key in ipairs(KEYS) do
        local pile=gs.foundation[key]; if not Array(pile,13) then return false end
        for i,card in ipairs(pile) do
            if not Card(card,true) or L:RankValue(card)~=i or i>1 and card.suit~=pile[1].suit then return false end
        end
        if #pile>0 then if suits[pile[1].suit] then return false end; suits[pile[1].suit]=true end
    end
    for i=1,7 do
        local pile=gs.tableau[i]; if not Array(pile) then return false end
        local open=false
        for j,card in ipairs(pile) do
            if not Card(card) or open and not card.faceUp then return false end
            if card.faceUp and open and not L:CanPlaceOnTableau(card,pile[j-1]) then return false end
            open=open or card.faceUp
        end
        if #pile>0 and not pile[#pile].faceUp then return false end
    end
    return total==52
end
function L:ValidateSave(gs)
    if not self:ValidateBoard(gs) or not self:IsMode(gs.mode) or gs.saveVersion~=2 or gs.ruleVersion~=2
        or (gs.scoreVersion~=1 and gs.scoreVersion~=2) or type(gs.runId)~="string"
        or not Int(gs.actionScore) or not Int(gs.undoUsed) or not Int(gs.elapsedMs) or not Int(gs.wastePass) or gs.wastePass<1
        or gs.score~=math.max(0,gs.actionScore-15*gs.undoUsed) or gs.elapsed~=gs.elapsedMs/1000
        or not Array(gs.undoStack,20) then return false end
    if gs.phase~="PLAYING" and gs.phase~="AUTO" and gs.phase~="RESULT_PENDING" and gs.phase~="WIN" and gs.phase~="LOSS" then return false end
    if gs.scoreVersion==2 and gs.actionScore>745 then return false end
    for _,snap in ipairs(gs.undoStack) do
        if not self:ValidateBoard(snap) or not Int(snap.actionScore) or gs.scoreVersion==2 and snap.actionScore>745 or not Int(snap.wastePass) or snap.wastePass<1 then return false end
    end
    local result=gs.phase=="WIN" or gs.phase=="LOSS" or gs.phase=="RESULT_PENDING"
    if result then
        if gs.result~="WIN" and gs.result~="LOSS" then return false end
        if gs.result=="WIN" and not self:IsWin(gs) then return false end
        if gs.phase~="RESULT_PENDING" and gs.phase~=gs.result then return false end
    elseif gs.result or self:IsWin(gs) then return false end
    return true
end
