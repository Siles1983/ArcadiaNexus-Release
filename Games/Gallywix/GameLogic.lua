-- Pure solo rules. Wheel geometry remains in Logic.lua.
local A = ArcadiaNexus
A.GWX_GameLogic = {}
local L = A.GWX_GameLogic
L.VOWEL_COST, L.SOLVE_BONUS, L.ROUND_COUNT = 250, 500, 3
local vowels = { A=true, E=true, I=true, O=true, U=true }
local function facts(s) return s.playerFacts and s.playerFacts[s.active] or s.achievementStats end
local function roundFacts(s) return s.roundFactsBySeat and s.roundFactsBySeat[s.active] or s.roundFacts end
local function human(s) return s.active<=(s.humanSeats or 1) end
local replacements = { ["ä"]="AE", ["Ä"]="AE", ["ö"]="OE", ["Ö"]="OE", ["ü"]="UE", ["Ü"]="UE", ["ß"]="SS", ["ẞ"]="SS" }
function L:Normalize(text)
    if type(text) ~= "string" then return nil end
    for from, to in pairs(replacements) do text = text:gsub(from, to) end
    text = text:upper():gsub("%s+", " "):match("^%s*(.-)%s*$")
    if text == "" or #text > 64 or not text:find("[A-Z]") or text:find("[^A-Z '%-!?,%.]") then return nil end
    return text
end
function L:IsVowel(letter) return vowels[letter] == true end
function L:NewGame(deck, seatCount, humanSeats)
    if not deck or #deck < self.ROUND_COUNT then return nil end
    local state = { deck=deck, round=0, active=1, players={}, turns=0, solved=0, unranked=false,
        achievementStats={mistakes=0, interventions=0, categories={}} }
    state.humanSeats=humanSeats or 1
    state.playerFacts={}
    for i=1,(seatCount or 3) do
        state.players[i] = { total=0, bank=0, extra=0, rounds=0 }
        state.playerFacts[i]={mistakes=0,interventions=0,categories={}}
    end
    state.achievementStats=state.playerFacts[1]
    if not self:NextRound(state) then return nil end
    return state
end
function L:NextRound(s)
    if s.round >= self.ROUND_COUNT then return false end
    s.round = s.round + 1
    local entry = s.deck[s.round]
    s.roundFacts = {vowelBought=false, lostBank=false, luckySpin=false}
    s.roundFactsBySeat={}
    for i=1,#s.players do s.roundFactsBySeat[i]={vowelBought=false,lostBank=false,luckySpin=false} end
    s.roundFacts=s.roundFactsBySeat[1]
    s.puzzle = { id=entry.id, category=entry.category, answer=self:Normalize(entry.answer), guessed={}, revealed={}, failedSolutions={} }
    if not s.puzzle.answer then return false end
    for i=1,#s.puzzle.answer do s.puzzle.revealed[i] = not s.puzzle.answer:sub(i,i):match("[A-Z]") end
    for _, p in ipairs(s.players) do p.bank, p.extra = 0, 0 end
    s.active, s.phase, s.value, s.event = (s.round-1+(s.firstStarter or 1)-1)%#s.players+1, "CHOICE", nil, {kind="round_start"}
    return true
end
function L:IsComplete(s)
    for i=1,#s.puzzle.answer do if not s.puzzle.revealed[i] then return false end end
    return true
end
function L:LoseTurn(s, reason)
    local p = s.players[s.active]
    local protected = p.extra > 0
    roundFacts(s).luckySpin=false
    if protected then p.extra = p.extra-1 else s.active = s.active%#s.players+1 end
    s.phase, s.value = "CHOICE", nil
    s.turns = s.turns+1
    s.event = {kind=reason, protected=protected}
end
function L:ApplySpin(s, index, intervention)
    if s.phase ~= "SPINNING" or not A.GWX_Logic:IsValidIndex(index) then return false end
    local value, p = A.GWX_Logic.fields[index], s.players[s.active]
    local human=human(s)
    local natural=human and intervention and not intervention.forced and s.gallywixEnabled
    roundFacts(s).luckySpin=false
    if natural then
        facts(s).interventions=facts(s).interventions+1
        roundFacts(s).luckySpin=A.GWX_Logic.fields[intervention.original]=="bankrupt" and value==1000
    end
    if type(value) == "number" then
        s.phase, s.value, s.event = "LETTER", value, {kind="money", value=value}
        local available = self:Available(s, false)
        if #available == 0 then s.phase, s.value = "CHOICE", nil; roundFacts(s).luckySpin=false end
    elseif value == "bankrupt" then
        if human then
            if p.bank>0 then roundFacts(s).lostBank=true end
            if p.extra>0 then facts(s).insured=1 end
            if natural and p.bank>=3000 then facts(s).gallywixBankrupt=1 end
        end
        p.bank = 0
        self:LoseTurn(s, "bankrupt")
    elseif value == "lose_turn" then self:LoseTurn(s, "lose_turn")
    else
        p.extra = p.extra+1
        s.phase, s.value, s.event = "CHOICE", nil, {kind="extra_spin"}
    end
    return true
end
function L:Available(s, vowel)
    local result = {}
    for i=65,90 do
        local letter = string.char(i)
        if not s.puzzle.guessed[letter] and self:IsVowel(letter) == vowel then result[#result+1] = letter end
    end
    return result
end
function L:BuyVowel(s)
    if s.phase ~= "CHOICE" or s.players[s.active].bank < self.VOWEL_COST or #self:Available(s, true) == 0 then return false end
    s.players[s.active].bank = s.players[s.active].bank-self.VOWEL_COST
    if human(s) then roundFacts(s).vowelBought=true end
    roundFacts(s).luckySpin=false
    s.phase, s.event = "VOWEL", {kind="vowel"}
    return true
end
function L:Guess(s, letter)
    letter = self:Normalize(letter)
    if not letter or not letter:match("^[A-Z]$") or s.puzzle.guessed[letter] then return false end
    if s.phase ~= "LETTER" and s.phase ~= "VOWEL" then return false end
    if self:IsVowel(letter) ~= (s.phase == "VOWEL") then return false end
    local positions = {}
    s.puzzle.guessed[letter] = true
    for i=1,#s.puzzle.answer do
        if s.puzzle.answer:sub(i,i) == letter then
            s.puzzle.revealed[i] = true
            positions[#positions+1] = i
        end
    end
    local amount = s.phase == "LETTER" and (s.value or 0)*#positions or 0
    if human(s) then
        if #positions==0 then facts(s).mistakes=facts(s).mistakes+1 end
        if amount>=5000 then facts(s).goldLetter=1 end
        if roundFacts(s).luckySpin and #positions>0 and s.phase=="LETTER" then facts(s).lucky=1 end
    end
    roundFacts(s).luckySpin=false
    s.players[s.active].bank = s.players[s.active].bank+amount
    if #positions == 0 then
        self:LoseTurn(s, "miss")
        s.event.letter = letter
    else
        s.phase = "REVEAL"
        s.event = {kind="hit", letter=letter, amount=amount, positions=positions}
    end
    return true
end
function L:FinishRound(s)
    local p = s.players[s.active]
    p.total = p.total+p.bank+self.SOLVE_BONUS
    p.rounds = p.rounds+1
    if human(s) then
        facts(s).categories[s.puzzle.category]=1
        if not roundFacts(s).vowelBought then facts(s).noVowels=1 end
        if roundFacts(s).lostBank then facts(s).comeback=1 end
    end
    s.solved = s.solved+1
    for i=1,#s.puzzle.answer do s.puzzle.revealed[i] = true end
    s.phase, s.event = "ROUND_END", {kind="round_won", winner=s.active, answer=s.puzzle.answer}
end
function L:Solve(s, answer)
    if s.phase ~= "CHOICE" then return false end
    local normalized = self:Normalize(answer)
    if not normalized then return false end
    if normalized == s.puzzle.answer then self:FinishRound(s) else
        if human(s) then facts(s).mistakes=facts(s).mistakes+1 end
        s.puzzle.failedSolutions[normalized] = true
        self:LoseTurn(s, "wrong_solution")
    end
    return true
end
-- Numeric result facts go through ScoreManager's existing max aggregation.
-- The cumulative round count is carried forward within the frozen variant.
function L:AchievementResult(s, previous, seat)
    seat=seat or 1
    local facts=s.playerFacts and s.playerFacts[seat] or s.achievementStats
    local won=self:Result(s,seat)=="WIN"
    local stats={roundsSolved=s.players[seat].rounds,
        gwxRoundsTotal=((previous or {}).gwxRoundsTotal or 0)+s.players[seat].rounds,
        gwxClean=won and facts.mistakes==0 and 1 or 0,
        gwxSweep=s.players[seat].rounds==self.ROUND_COUNT and 1 or 0,
        gwxDefiant=won and s.gallywixEnabled and facts.interventions>=3 and 1 or 0}
    for _,key in ipairs({"noVowels","goldLetter","insured","comeback","gallywixBankrupt","lucky"}) do
        stats["gwx_"..key]=facts[key] or 0
    end
    for _,category in ipairs({"characters","places","weapons","lore"}) do
        stats["gwxCategory_"..category]=facts.categories[category] or 0
    end
    return stats
end
function L:FinishReveal(s)
    if s.phase ~= "REVEAL" then return false end
    if self:IsComplete(s) then self:FinishRound(s) else s.phase, s.value = "CHOICE", nil end
    return true
end
function L:Result(s, seat)
    seat=seat or 1
    for i,p in ipairs(s.players) do if p.total>s.players[seat].total then return "LOSS" end end
    for i,p in ipairs(s.players) do if i~=seat and p.total==s.players[seat].total then return "DRAW" end end
    return "WIN"
end
-- Match catalogue candidates against the public board, never hidden characters.
function L:Candidates(s, locale)
    local result = {}
    for _, entry in ipairs(A.GWX_Words:GetEntries(s.puzzle.category,locale)) do
        local answer = self:Normalize(entry.answer)
        local fits = answer and #answer == #s.puzzle.answer and not s.puzzle.failedSolutions[answer]
        if fits then
            for i=1,#answer do
                local letter = answer:sub(i,i)
                if (s.puzzle.revealed[i] and letter ~= s.puzzle.answer:sub(i,i))
                    or (not s.puzzle.revealed[i] and (s.puzzle.guessed[letter] or not letter:match("[A-Z]"))) then
                    fits = false; break
                end
            end
        end
        if fits then result[#result+1] = answer end
    end
    return result
end
-- Word wrapping is data, not UI geometry. Indices stay tied to the puzzle.
function L:LayoutPuzzle(answer, columns)
    columns = columns or 16
    local rows, row, start = {}, {}, 1
    while start <= #answer do
        local finish = answer:find(" ",start,true) or (#answer+1)
        local length = finish-start
        if #row > 0 and #row+1+length > columns then rows[#rows+1]=row; row={} end
        if #row > 0 then row[#row+1]=0 end
        for i=start,finish-1 do
            if #row == columns then rows[#rows+1]=row; row={} end
            row[#row+1]=i
        end
        start=finish+1
    end
    if #row>0 then rows[#rows+1]=row end
    local result={}
    for y, indices in ipairs(rows) do
        local offset=math.floor((columns-#indices)/2)
        for x, index in ipairs(indices) do
            if index>0 then result[#result+1]={index=index,row=y,column=x+offset} end
        end
    end
    return result, #rows
end
function L:ChooseAI(s, locale)
    if s.phase == "CHOICE" then
        local shown, letters = 0, 0
        for i=1,#s.puzzle.answer do
            if not s.puzzle.revealed[i] or s.puzzle.answer:sub(i,i):match("[A-Z]") then
                letters=letters+1
                if s.puzzle.revealed[i] then shown=shown+1 end
            end
        end
        local candidates=self:Candidates(s,locale)
        if #candidates==1 and (shown/math.max(1,letters)>=0.65 or #self:Available(s,false)==0) then
            return "solve",candidates[1]
        end
        if s.players[s.active].bank >= self.VOWEL_COST and #self:Available(s, true) > 0 then return "vowel" end
        if #self:Available(s, false) == 0 then
            if #candidates>0 then return "solve",candidates[1] end
            return "pass"
        end
        return "spin"
    end
    if s.phase ~= "LETTER" and s.phase ~= "VOWEL" then return nil end
    local order = locale == "deDE" and "ENIRSTADHULCGMOBWFKZPVJYXQ" or "ETAOINSHRDLUCMFWYPVBGKJQXZ"
    for i=1,#order do
        local letter = order:sub(i,i)
        if not s.puzzle.guessed[letter] and self:IsVowel(letter) == (s.phase == "VOWEL") then return "letter", letter end
    end
end

-- Local snapshots contain data only; reject malformed or incompatible continuations.
function L.Copy(value,seen,depth)
    if type(value)~="table" then if type(value)=="function" then return nil end; return value end
    seen,depth=seen or {},depth or 0
    if seen[value] or depth>32 then return nil end
    seen[value]=true
    local out={}; for k,v in pairs(value) do out[k]=L.Copy(v,seen,depth+1) end
    seen[value]=nil; return out
end
function L:ValidateSave(save)
    local function validate()
        local function int(n,lo,hi) return type(n)=="number" and n%1==0 and n>=lo and n<=hi end
        local function number(n,hi) return type(n)=="number" and n>=0 and n<=hi end
        assert(type(save)=="table" and save.version==1 and type(save.runId)=="string" and #save.runId<128)
        local s=save.game
        assert(type(s)=="table" and (s.locale=="deDE" or s.locale=="enUS"))
        assert(type(s.gallywixEnabled)=="boolean" and s.difficulty==(s.gallywixEnabled and "gallywix" or "default"))
        assert(not A.LocalResults or not A.LocalResults.GetSerial or A.LocalResults:GetSerial("GALLYWIX",save.runId))
        assert(type(s.unranked)=="boolean" and type(save.finished)=="boolean" and type(save.emitted)=="boolean")
        local catalogue={}; for _,e in ipairs(A.GWX_Words:GetEntries(s.category,s.locale)) do catalogue[e.id]=e end
        assert(type(s.deck)=="table" and #s.deck==3)
        local seen={}
        for _,e in ipairs(s.deck) do
            assert(type(e)=="table" and catalogue[e.id] and not seen[e.id])
            assert(e.answer==catalogue[e.id].answer and e.category==catalogue[e.id].category); seen[e.id]=true
        end
        assert(int(s.round,1,3) and int(s.active,1,3) and s.humanSeats==1 and #s.players==3)
        assert(({CHOICE=true,SPINNING=true,LETTER=true,VOWEL=true,REVEAL=true,ROUND_END=true})[s.phase])
        assert(int(s.turns,0,2147483647) and int(s.solved,0,3))
        assert(s.solved==s.round-(s.phase=="ROUND_END" and 0 or 1))
        for _,p in ipairs(s.players) do
            assert(type(p)=="table")
            for _,key in ipairs({"bank","total","extra","rounds"}) do assert(int(p[key],0,2147483647)) end
            assert(p.rounds<=3)
        end
        for i=1,3 do
            local f=s.playerFacts[i]; assert(type(f)=="table" and type(f.categories)=="table")
            assert(int(f.mistakes,0,2147483647) and int(f.interventions,0,2147483647))
            local rf=s.roundFactsBySeat[i]; assert(type(rf)=="table")
            for _,k in ipairs({"vowelBought","lostBank","luckySpin"}) do assert(type(rf[k])=="boolean") end
        end
        local puzzle=s.puzzle
        assert(puzzle.id==s.deck[s.round].id and puzzle.category==s.deck[s.round].category and puzzle.answer==self:Normalize(s.deck[s.round].answer))
        assert(type(puzzle.guessed)=="table" and type(puzzle.revealed)=="table" and type(puzzle.failedSolutions)=="table")
        for k,v in pairs(puzzle.guessed) do assert(type(k)=="string" and k:match("^[A-Z]$") and v==true) end
        for i=1,#puzzle.answer do
            local c=puzzle.answer:sub(i,i)
            assert(type(puzzle.revealed[i])=="boolean" and puzzle.revealed[i]==(s.phase=="ROUND_END" or not c:match("[A-Z]") or puzzle.guessed[c]==true))
        end
        for k,v in pairs(puzzle.failedSolutions) do assert(type(k)=="string" and self:Normalize(k)==k and v==true) end
        assert(type(s.event)=="table" and type(s.event.kind)=="string" and number(save.rotation,360))
        local jobs={reveal=true,ai=true,finish=true,landed=true,apply=true,intervention_pause=true,laugh=true,entrance=true,intervention_spin=true}
        local p,m,spin=save.pending,save.motion,save.spin
        assert(not (p and m) and not (p and spin)) -- motion expands before the reserved spin starts.
        if p then assert(jobs[p.kind] and p.kind~="intervention_pause" and number(p.remaining,10)) end
        if m then assert((m.mode=="expand" or m.mode=="dock") and m.duration==(m.mode=="expand" and 0.4 or 0.65) and number(m.elapsed,m.duration) and (m.kind==nil or m.kind=="apply" or m.kind=="intervention_pause")) end
        if spin then
            assert(s.phase=="SPINNING" and A.GWX_Logic:IsValidIndex(spin.index))
            assert(spin.duration==(spin.intervention and 3.5 or 4.5) and number(spin.elapsed,spin.duration))
            assert(number(spin.startDegrees,360) and spin.distance==A.GWX_Logic:GetSpinDistance(spin.startDegrees,spin.index,spin.intervention and 2 or 5) and spin.targetDegrees==A.GWX_Logic:GetTargetDegrees(spin.index))
            assert(spin.interventionTarget==nil or A.GWX_Logic:IsValidIndex(spin.interventionTarget))
        end
        if save.intervention then
            assert(A.GWX_Logic:IsValidIndex(save.intervention.target) and A.GWX_Logic:IsValidIndex(save.intervention.original) and type(save.intervention.forced)=="boolean")
            assert(not save.intervention.forced or s.unranked)
        end
        if p and (p.kind=="laugh" or p.kind=="entrance" or p.kind=="intervention_spin" or p.kind=="apply")
            or m and m.kind=="intervention_pause" or spin and spin.intervention then assert(save.intervention) end
        if spin and spin.intervention then assert(spin.index==save.intervention.target) end
        if spin and spin.forcedIntervention then assert(s.unranked) end
        if s.phase=="SPINNING" then
            assert(spin or m or p)
            if p then assert(p.kind~="reveal" and p.kind~="ai" and p.kind~="finish") end
            if p and p.kind~="landed" or m and m.kind then assert(A.GWX_Logic:IsValidIndex(save.lastIndex)) end
        elseif p then
            assert(p.kind=="reveal" and s.phase=="REVEAL" or p.kind=="finish" and s.phase=="ROUND_END" and s.round==3
                or p.kind=="ai" and s.active~=1 and (s.phase=="CHOICE" or s.phase=="LETTER" or s.phase=="VOWEL"))
        end
        if s.phase=="REVEAL" then assert(p and p.kind=="reveal") end
        if s.phase=="ROUND_END" and s.round==3 and not save.finished then assert(p and p.kind=="finish") end
        if s.active~=1 and (s.phase=="CHOICE" or s.phase=="LETTER" or s.phase=="VOWEL") then assert(p and p.kind=="ai") end
        if s.phase=="LETTER" then assert(number(s.value,1000) and s.value>0) end
        if save.finished or save.emitted then
            assert(s.round==3 and s.phase=="ROUND_END" and not p and not m and not spin)
            local d=save.terminal
            assert(type(d)=="table" and d.runId==save.runId and d.gameId=="GALLYWIX" and d.ruleVersion==1)
            assert(d.difficulty==s.difficulty and d.result==self:Result(s) and d.score==s.players[1].total and d.category==s.category and d.locale==s.locale)
            assert(type(d.stats)=="table" and d.stats.roundsSolved==s.players[1].rounds)
        end
        return true
    end
    local ok,result=pcall(validate); return ok and result==true, not ok and tostring(result) or nil
end
