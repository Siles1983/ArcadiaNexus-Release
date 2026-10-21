-- Host-owned rules and compact public snapshots. No puzzle ID or hidden answer
-- leaves _hostHidden. START carries seats only; SNAPSHOT carries the board.
local A=ArcadiaNexus
A.GWX_Match={}
local M=A.GWX_Match
local L=A.GWX_GameLogic
local categories={"all","characters","places","weapons","lore"}
local phases={"CHOICE","SPINNING","LETTER","VOWEL","REVEAL","ROUND_END"}
local events={"round_start","money","hit","miss","round_won","bankrupt","lose_turn","extra_spin","vowel","wrong_solution","pass"}
local factKeys={"noVowels","goldLetter","insured","comeback","gallywixBankrupt","lucky"}
local function index(t,value) for i,v in ipairs(t) do if v==value then return i end end; return 1 end
local function split(s,sep)
    local out={}; for v in (s..sep):gmatch("(.-)"..sep) do out[#out+1]=v end; return out
end
local function enc(n)
    n=math.max(0,math.floor(tonumber(n) or 0)); if n==0 then return "0" end
    local out=""; repeat local d=n%36; out=string.sub("0123456789abcdefghijklmnopqrstuvwxyz",d+1,d+1)..out; n=math.floor(n/36) until n==0
    return out
end
local function dec(s) return tonumber(s,36) or 0 end
local function has(n,bit) return math.floor(n/2^bit)%2==1 end
local function factMask(f)
    local n=(f.mistakes>0 and 1 or 0)+(f.interventions>=3 and 2 or 0)
    for i,key in ipairs(factKeys) do if f[key] then n=n+2^(i+1) end end
    for i=2,5 do if f.categories[categories[i]] then n=n+2^(i+6) end end
    return n
end
local function restoreFacts(n)
    local f={mistakes=has(n,0) and 1 or 0,interventions=has(n,1) and 3 or 0,categories={}}
    for i,key in ipairs(factKeys) do if has(n,i+1) then f[key]=1 end end
    for i=2,5 do if has(n,i+6) then f.categories[categories[i]]=1 end end
    return f
end
function M.Empty()
    return {category="all",locale="deDE",bot="none",gallywix=false,stage=0,elapsed=0}
end
function M.Refresh(pub,hid)
    local s=hid.game
    local chars={}
    for i=1,#s.puzzle.answer do chars[i]=s.puzzle.revealed[i] and s.puzzle.answer:sub(i,i) or "_" end
    pub.mask=table.concat(chars); pub.round=s.round; pub.active=s.active
    pub.phase=s.phase; pub.value=s.value or 0; pub.category=s.puzzle.category
    pub.humans=s.humanSeats; pub.firstStarter=s.firstStarter or 1; pub.players={}; pub.playerFacts={}
    for i,p in ipairs(s.players) do
        pub.players[i]={bank=p.bank,total=p.total,extra=p.extra,rounds=p.rounds}
        pub.playerFacts[i]=restoreFacts(factMask(s.playerFacts[i]))
    end
    pub.guessed={}; for k,v in pairs(s.puzzle.guessed) do pub.guessed[k]=v end
    local e=s.event or {}; pub.event={kind=e.kind,letter=e.letter,amount=e.amount or 0,
        value=e.value,winner=e.winner,protected=e.protected}
    pub.over=s.round==3 and s.phase=="ROUND_END" and pub.stage==0
end
function M.Pack(pub)
    if not pub.mask then
        return {gx=table.concat({index(categories,pub.category),pub.locale=="deDE" and 1 or 0,
            pub.bot=="Gazlowe" and 1 or pub.bot=="Rexxar" and 2 or 0,pub.gallywix and 1 or 0},",")}
    end
    local guessed=0; for i=65,90 do if pub.guessed[string.char(i)] then guessed=guessed+2^(i-65) end end
    local meta={pub.round,pub.active,index(phases,pub.phase),pub.value,pub.humans,pub.stage,
        pub.first or 0,pub.final or 0,pub.spinId or 0,math.floor((pub.elapsed or 0)*1000),
        pub.rotation or 0,index(categories,pub.category),pub.locale=="deDE" and 1 or 0,
        pub.bot=="Gazlowe" and 1 or pub.bot=="Rexxar" and 2 or 0,pub.gallywix and 1 or 0,guessed,
        index(events,pub.event.kind),pub.event.amount or 0,pub.event.protected and 1 or 0,pub.firstStarter or 1,index(categories,pub.selectedCategory or pub.category)}
    for i,v in ipairs(meta) do meta[i]=enc(v) end
    local accounts={}
    for i,p in ipairs(pub.players) do
        accounts[i]=table.concat({enc(p.bank),enc(p.total),enc(p.extra),enc(p.rounds),enc(factMask(pub.playerFacts[i]))},",")
    end
    return {gx=table.concat({table.concat(meta,","),pub.mask,pub.event.letter or "",table.concat(accounts,";")},"~")}
end
function M.Unpack(pub,fields)
    if not fields.gx then return end
    local parts=split(fields.gx,"~")
    if #parts==1 then
        local c=split(parts[1],",")
        pub.category=categories[tonumber(c[1])] or "all"; pub.locale=c[2]=="1" and "deDE" or "enUS"
        pub.bot=c[3]=="1" and "Gazlowe" or c[3]=="2" and "Rexxar" or "none"; pub.gallywix=c[4]=="1"
        return
    end
    if #parts~=4 or #parts[2]>64 or parts[2]:find("[^A-Z_ '%-!?,%.]") then return end
    local raw=split(parts[1],","); if #raw~=21 then return end
    local m={}; for i,v in ipairs(raw) do m[i]=dec(v) end
    pub.round,pub.active,pub.phase,pub.value,pub.humans,pub.stage=m[1],m[2],phases[m[3]],m[4],m[5],m[6]
    pub.first,pub.final,pub.spinId,pub.elapsed,pub.rotation=m[7],m[8],m[9],m[10]/1000,m[11]
    pub.category=categories[m[12]]; pub.locale=m[13]==1 and "deDE" or "enUS"
    pub.bot=m[14]==1 and "Gazlowe" or m[14]==2 and "Rexxar" or "none"; pub.gallywix=m[15]==1
    pub.mask=parts[2]; pub.guessed={}
    for i=65,90 do if has(m[16],i-65) then pub.guessed[string.char(i)]=true end end
    pub.firstStarter=m[20]; pub.selectedCategory=categories[m[21]]
    pub.players={}; pub.playerFacts={}
    for i,account in ipairs(split(parts[4],";")) do
        local v=split(account,",")
        if #v~=5 then return end
        pub.players[i]={bank=dec(v[1]),total=dec(v[2]),extra=dec(v[3]),rounds=dec(v[4])}
        pub.playerFacts[i]=restoreFacts(dec(v[5]))
    end
    pub.event={kind=events[m[17]],letter=parts[3]~="" and parts[3] or nil,amount=m[18],protected=m[19]==1,
        value=pub.value,winner=pub.active}
    pub.over=pub.round==3 and pub.phase=="ROUND_END" and pub.stage==0
end
function M.Format(pub)
    local format=pub.humans==3 and "3p" or #pub.players==3 and "2p_ai" or "2p"
    return "match_"..format..(pub.gallywix and "_gallywix" or "")
end
function M.Board(pub,seat)
    if not pub.mask then return nil end
    local revealed={}; for i=1,#pub.mask do revealed[i]=pub.mask:sub(i,i)~="_" end
    local e={}; for k,v in pairs(pub.event or {}) do e[k]=v end
    e.positions={}
    if e.kind=="hit" and e.letter then
        for i=1,#pub.mask do if pub.mask:sub(i,i)==e.letter then e.positions[#e.positions+1]=i end end
    end
    if e.kind=="round_won" then e.answer=pub.mask end
    return {round=pub.round,active=pub.active,phase=pub.phase,value=pub.value,
        localSeat=seat,humanSeats=pub.humans,players=pub.players,playerFacts=pub.playerFacts,
        gallywixEnabled=pub.gallywix,difficulty=M.Format(pub),firstStarter=pub.firstStarter,locale=pub.locale,category=pub.selectedCategory or pub.category,
        puzzle={answer=pub.mask,category=pub.category,guessed=pub.guessed,revealed=revealed},event=e}
end
function M.Ready(node)
    local count=0
    for i=1,3 do if node.seats[i] then count=count+1; if not node.ready[i] then return false end end end
    return count>=2
end
-- Stage 0 is interactive. Every other stage is advanced only by the host's
-- session-owned clock; a client cannot shorten a spin by sending STEP.
M.Durations={0.4,4.5,0.65,0.65,0.65,4,0.5,3.5,1.5,1.3}
function M.Stage(pub,hid,stage)
    pub.stage=stage; pub.elapsed=0
    local duration=stage==10 and (0.7+#(hid.game.event.positions or {})*0.1) or M.Durations[stage]
    hid.deadline=GetTime()+duration
end
function M.Apply(pub,intent,seat,hid)
    if not hid or not hid.game then return false end
    local s=hid.game
    if intent.kind=="STEP" then
        if seat~=1 or pub.stage==0 or GetTime()<hid.deadline then return false end
        local stage=pub.stage
        if stage==10 then L:FinishReveal(s); pub.stage=0
        elseif stage==9 then
            L:ApplySpin(s,pub.final,{original=pub.first,forced=false}); pub.rotation=A.GWX_Logic:GetTargetDegrees(pub.final); pub.stage=0
        elseif stage==4 then
            pub.rotation=A.GWX_Logic:GetTargetDegrees(pub.first)
            if hid.target then M.Stage(pub,hid,5) else L:ApplySpin(s,pub.first); pub.stage=0 end
        elseif stage==6 then pub.final=hid.target; M.Stage(pub,hid,7)
        else M.Stage(pub,hid,stage+1) end
    elseif intent.kind=="AI" then
        if seat~=1 or s.active<=s.humanSeats or pub.stage~=0 or GetTime()<(hid.aiAt or 0) then return false end
        local action,value=L:ChooseAI(s,pub.locale)
        return M.ApplyAction(pub,hid,action,value)
    else
        if pub.stage~=0 or seat>s.humanSeats then return false end
        if intent.kind~="next" and seat~=s.active then return false end
        return M.ApplyAction(pub,hid,intent.kind,intent.c)
    end
    M.Refresh(pub,hid); hid.aiAt=GetTime()+1
    return true
end
function M.ApplyAction(pub,hid,action,value)
    local s=hid.game; local ok=false
    if action=="spin" and s.phase=="CHOICE" then
        pub.first=A.GWX_Logic:SelectIndex("random")
        hid.target=A.GWX_Logic:SelectIntervention(s.gallywixEnabled,"auto","random",pub.first)
        pub.final=0; pub.spinId=(pub.spinId or 0)+1; s.phase="SPINNING"
        M.Stage(pub,hid,1); ok=true
    elseif action=="vowel" then ok=L:BuyVowel(s)
    elseif action=="letter" then ok=L:Guess(s,value); if ok and s.phase=="REVEAL" then M.Stage(pub,hid,10) end
    elseif action=="solve" then ok=L:Solve(s,value)
    elseif action=="next" and s.phase=="ROUND_END" and s.round<3 then ok=L:NextRound(s)
    elseif action=="pass" and s.active>s.humanSeats then L:LoseTurn(s,"pass"); ok=true end
    if ok then M.Refresh(pub,hid); hid.aiAt=GetTime()+1 end
    return ok
end
function M.Options(engine)
    return {gameId="GALLYWIX",gameProto=2,maxSeats=3,newPublic=M.Empty,
        packLobby=M.Pack,packPublic=M.Pack,unpackLobby=M.Unpack,unpackPublic=M.Unpack,
        privateForSeat=function() return nil end,canTryStart=M.Ready,
        assignSeats=function(node)
            local seats={}; for i=1,3 do if node.seats[i] then seats[#seats+1]=node.seats[i] end end
            node.seats=seats; return true
        end,
        seedOnStart=function()
            local node=engine.match; local config=node.publicState
            local humans=#node.seats; local bot=humans==3 and "none" or config.bot
            local s=L:NewGame(A.GWX_Words:NewDeck(config.category,config.locale),humans+(bot~="none" and 1 or 0),humans)
            s.firstStarter=#s.players==2 and math.random(1,2) or 1
            s.active=s.firstStarter
            s.gallywixEnabled=config.gallywix
            local pub=M.Empty(); pub.selectedCategory=config.category; pub.bot=bot; pub.locale=config.locale; pub.gallywix=config.gallywix
            local hid={game=s,aiAt=GetTime()+1}; M.Refresh(pub,hid); return pub,hid
        end,
        applyIntent=M.Apply,isFinished=function(pub) return pub.over==true end,
        onState=function(node,state) if engine.match==node then engine:OnMatchState(state) end end,
        onPublic=function(node) if engine.match==node then engine:OnMatchPublic() end end,
        onReject=function(node,fields) if engine.match==node then engine:OnMatchReject(fields) end end,
        onResult=function(node,id) if engine.match==node then return engine:OnMatchResult(node,id) end end}
end
