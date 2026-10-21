-- Opt-in local result receipts for the modernized games.
-- All progression mutations and their receipt are prepared together, then
-- published before UI notification. Failure leaves the original data intact.
local A = _G.ArcadiaNexus
local LR = {}
A.LocalResults = LR
local ROOTS = { "leaderboard", "profile", "achievements", "challenges", "streak", "tavernGold", "localResults" }
local CONSUMERS = {["2048"]=true,CODEBREAKER=true,MINESWEEPER=true,SUDOKU=true,BLACKJACK=true,HIGHERORLOWER=true,SOLITAIRE=true,TAVERNCARDS=true,ARCADIASECHO=true,SHELLGAME=true,REACTIONSTRIKE=true,TICTACTOE=true,WHACKAMOLE=true,ALIENDEFENSE=true,BUBBLESHOOTER=true,ARGUSORBDEFENSE=true,BARREL_BRAWL=true,BLOCKBREAKER=true,BLOCKDROP=true,DARKMOON_PINBALL=true,GOBLINBLAST=true,SNAKE=true}
function LR:Supports(gameId) return CONSUMERS[gameId]==true end
CONSUMERS.AZEROTHCONQUEST = true
CONSUMERS.BACKGAMMON = true
CONSUMERS.LOA = true
CONSUMERS.GALLYWIX = true
CONSUMERS.ALCHEMISTSSORT = true
CONSUMERS.MOSAICOFAZEROTH = true
CONSUMERS.NONOGRAM = true
CONSUMERS.SHADOWSCONQUEST = true
CONSUMERS.HANGMAN = true

local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Copy(v) end
    return out
end

local function Commit(target, source)
    for k in pairs(target) do if source[k] == nil then target[k] = nil end end
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then Commit(target[k], v)
        else target[k] = v end
    end
end

function LR:GetJournal()
    local db = _G.ArcadiaNexusDB
    if type(db.localResults) ~= "table" then db.localResults = { serial = 0, receipts = {}, issued = {}, retiredThrough = 0 } end
    return db.localResults
end

-- This journal owns local run identities and receipts independently of game slots.
-- Slot cleanup must preserve receipts pinned by active or recoverable runs.
function LR:NewRun(gameId)
    assert(self:Supports(gameId), "Unsupported local result consumer")
    local j = self:GetJournal()
    if not j.namespace then
        j.namespace = tostring(GetServerTime()) .. ":" .. tostring(UnitGUID and UnitGUID("player") or "local")
            .. ":" .. tostring(math.random(1, 2147483646))
    end
    j.serial = j.serial + 1
    local id = j.namespace .. ":" .. gameId .. ":" .. j.serial
    j.issued[id] = j.serial
    return id
end

function LR:GetSerial(gameId, runId)
    local j = self:GetJournal()
    if type(runId) ~= "string" or not j.namespace then return nil end
    local prefix = j.namespace .. ":" .. gameId .. ":"
    if runId:sub(1, #prefix) ~= prefix then return nil end
    local n = tonumber(runId:sub(#prefix + 1))
    if not n or n < 1 or n > j.serial or n ~= math.floor(n) then return nil end
    return n
end

function LR:GetReceipt(runId) return self:GetJournal().receipts[runId] end

function LR:Prune(protectedRunId)
    local j, pinned = self:GetJournal(), {}
    local cutoff = math.max(0, j.serial - 256)
    -- Extra protection exists only for this pass. It is not stored.
    if type(protectedRunId)=="string" then pinned[protectedRunId]=true end
    for _,settings in pairs(_G.ArcadiaNexusDB.gameSettings or {}) do
        if type(settings)=="table" then
            for _,key in ipairs({"slots","saves","pendingResults"}) do
                for _,save in pairs(type(settings[key])=="table" and settings[key] or {}) do
                    if type(save)=="table" and save.runId then pinned[save.runId]=true end
                end
            end
        end
    end
    for id, receipt in pairs(j.receipts) do
        if receipt.serial <= cutoff and not pinned[id] then j.receipts[id] = nil end
    end
    for id, serial in pairs(j.issued) do
        if serial <= cutoff and not pinned[id] then j.issued[id] = nil end
    end
    j.retiredThrough = math.max(j.retiredThrough, cutoff)
end

function LR:IsPreparing() return self._preparing == true end

-- Only called from Engine:Emit while this opt-in transaction is preparing.
function LR:BufferEvent(event, ...)
    if not self._preparing then return false end
    local args, AM = { ... }, A.AchievementManager
    if event == "ACHIEVEMENT_XP" then
        local reward = args[1]
        if reward and reward.amount and reward.amount > 0 then A.XPManager:AddXP(reward.amount) end
        return true -- do not replay this reward-producing event after commit
    end
    if event == "ARCADE_LEVEL_UP" then AM:_CheckLevelGroups()
    elseif event == "CHALLENGE_COMPLETE" then
        AM:_CheckById("GLOBAL_DAILY_STREAK"); AM:_CheckById("GLOBAL_WEEKLY_STREAK")
    elseif event == "STREAK_UPDATED" then AM:_CheckById("GLOBAL_LOGIN_STREAK") end
    self._events[#self._events + 1] = { event = event, args = args, n = select("#", ...) }
    return true
end

function LR:Process(data)
    if self._preparing or self._publishing then return false end
    if type(data) ~= "table" then return false end
    data.processed, data.awardedXP, data.awardedGold = nil, 0, 0
    if not self:Supports(data.gameId) or data.resultId then return false end
    local alien = data.gameId == "ALIENDEFENSE"
    local orbit = data.gameId == "ARGUSORBDEFENSE"
    local breaker = data.gameId=="BLOCKBREAKER"
    local goblin = data.gameId=="GOBLINBLAST"
    local progress = alien or orbit or breaker or goblin
    if data.result ~= "WIN" and data.result ~= "LOSS" and not (progress and data.result == "STATS") and not ((data.gameId=="BLACKJACK" or data.gameId=="HIGHERORLOWER" or data.gameId=="TICTACTOE" or data.gameId=="GALLYWIX") and data.result=="DRAW") then return false end
    local mosaic=data.gameId=="MOSAICOFAZEROTH" and (data.difficulty=="v2_easy" or data.difficulty=="v2_medium" or data.difficulty=="v2_hard")
    local non=data.gameId=='NONOGRAM' and type(data.difficulty)=='string' and data.difficulty:match('^v2_')
    local sc=data.gameId=="SHADOWSCONQUEST" and type(data.difficulty)=="string" and data.difficulty:match("^v2_")
    if not orbit and not mosaic and not non and not sc and not (data.gameId=="GALLYWIX" and (data.difficulty=="default" or data.difficulty=="gallywix")) and not (data.gameId=="LOA" and (data.difficulty=="ai_1" or data.difficulty=="ai_2" or data.difficulty=="ai_3")) and data.difficulty ~= "easy" and data.difficulty ~= "normal" and data.difficulty ~= "hard" and not ((data.gameId=="BLACKJACK" and data.difficulty=="table") or (data.gameId=="HIGHERORLOWER" and A.HOL_Logic:IsVariant(data.difficulty)) or (data.gameId=="SOLITAIRE" and A.SOL_Logic:IsMode(data.difficulty)) or (data.gameId=="TAVERNCARDS" and type(data.difficulty)=="string" and data.difficulty:match("^solo_") and A.TC_Logic:IsDifficulty(data.difficulty:sub(6))) or (data.gameId=="SHELLGAME" and type(data.difficulty)=="string" and data.difficulty:match("^round_") and A.SHG_Logic:IsDifficulty(data.difficulty:sub(7))) or (data.gameId=="TICTACTOE" and type(data.difficulty)=="string" and data.difficulty:match("^solo_")) or (data.gameId=="DARKMOON_PINBALL" and (data.difficulty=="darkmoon_midway" or data.difficulty=="darkmoon_carousel")) or (data.gameId=="BUBBLESHOOTER" and type(data.difficulty)=="string" and data.difficulty==A.BS_Logic.ScoreKey(data.playMode,data.aiDifficulty))) then return false end
    local serial = self:GetSerial(data.gameId, data.runId)
    if not serial or type(data.score) ~= "number" or data.score < 0
        or data.score ~= data.score or data.score == math.huge then return false end
    local j = self:GetJournal()
    local old = j.receipts[data.runId]
    if not old and serial <= j.retiredThrough and not j.issued[data.runId] then return false end
    if old and (old.gameId ~= data.gameId or old.difficulty ~= data.difficulty or old.result ~= data.result and not (progress and old.result == "STATS")) then return false end
    if old and (data.gameId == "CODEBREAKER" or data.gameId == "SUDOKU") and old.score ~= data.score then return false end
    if data.gameId=="ALCHEMISTSSORT" and not A.ALS_Settings:ValidateResult(data,old) then return false end
    if data.gameId=="MOSAICOFAZEROTH" and not A.SLP_Settings:ValidateResult(data,old) then return false end
    if data.gameId=="NONOGRAM" and not A.NON_Settings:ValidateResult(data,old) then return false end
    if data.gameId=="SHADOWSCONQUEST" and not A.SC_Settings:ValidateResult(data,old) then return false end
    if data.gameId=="DARKMOON_PINBALL" then
        local st=data.stats
        local function integer(n) return type(n)=="number" and n>=0 and n<math.huge and n%1==0 end
        if data.ruleVersion~=2 or data.devRun or data.result~="LOSS" or not integer(data.score) or type(st)~="table" then return false end
        for _,key in ipairs({"maxCombo","bumperHits","ballSaves","kickbacks","tilts","multiballs","jackpots","missionsDone","distinctMissions","extraBalls","elapsed"}) do
            if not integer(st[key]) or old and old.personalStats[key]~=st[key] then return false end
        end
        if st.distinctMissions>4 or st.distinctMissions>st.missionsDone or st.extraBalls>1 or old and old.score~=data.score then return false end
    end
    if data.gameId=="BLOCKDROP" then
        local st=data.stats
        if data.ruleVersion~=2 or data.result~="LOSS" or data.difficulty~="normal" or data.score%1~=0
            or type(data.legacyContinuation)~="boolean" or type(st)~="table"
            or type(st.linesCleared)~="number" or st.linesCleared<0 or st.linesCleared>=math.huge or st.linesCleared%1~=0 then return false end
        if old and (old.score~=data.score or old.personalStats.linesCleared~=st.linesCleared or old.legacyContinuation~=data.legacyContinuation) then return false end
    end
    if data.gameId=="SNAKE" then
        local st=data.stats; local diff=A.SNK_Themes.DIFFICULTY[data.difficulty]
        local function int(n) return type(n)=="number" and n>=0 and n<math.huge and n%1==0 end
        if data.ruleVersion~=2 or not diff or type(st)~="table" or not int(st.length) or not int(st.fruitsEaten)
            or st.length~=st.fruitsEaten+3 or st.length>diff.gridSize^2 or data.score~=st.fruitsEaten*diff.multiplier
            or (data.result=="WIN")~=(st.length==diff.gridSize^2)
            or old and (old.score~=data.score or old.personalStats.length~=st.length or old.personalStats.fruitsEaten~=st.fruitsEaten) then return false end
    end
    if data.gameId=="AZEROTHCONQUEST" then
        local st=data.stats
        local function int(n) return type(n)=="number" and n%1==0 and n>=0 and n<=100 end
        if data.ruleVersion~=1 or type(st)~="table" or not int(st.shotsTotal) or st.shotsTotal<1
            or not int(st.misses) or not int(st.hits) or st.hits~=st.shotsTotal-st.misses or st.hits>17
            or data.result=="WIN" and st.hits~=17
            or type(st.hitRate)~="number" or st.hitRate~=st.hits/st.shotsTotal*100
            or data.score~=(data.result=="WIN" and ({easy=100,normal=150,hard=200})[data.difficulty] or 0) then return false end
        if old then
            if old.score~=data.score then return false end
            for _,key in ipairs({"shotsTotal","misses","hits","hitRate"}) do
                if old.personalStats[key]~=st[key] then return false end
            end
        end
        data.skipHighscores=true
    end
    if data.gameId=="BACKGAMMON" then
        local st=data.stats
        if data.ruleVersion~=1 or data.score~=0 or type(st)~="table" or type(st.pointsWon)~="number"
            or st.pointsWon%1~=0 or st.pointsWon<0 or st.pointsWon>3
            or data.result=="WIN" and st.pointsWon<1 or data.result=="LOSS" and st.pointsWon~=0
            or old and (old.score~=data.score or old.personalStats.pointsWon~=st.pointsWon) then return false end
        data.skipHighscores=true
    end
    if data.gameId=="GALLYWIX" then
        if data.ruleVersion~=1 or data.difficulty~="default" and data.difficulty~="gallywix" or data.score%1~=0 or type(data.stats)~="table" then return false end
        if old and old.score~=data.score then return false end
        for key,value in pairs(data.stats) do
            if type(value)~="number" or value<0 or value%1~=0 or value>2147483647 or old and old.personalStats[key]~=value then return false end
        end
        if type(data.stats.roundsSolved)~="number" or data.stats.roundsSolved>3 then return false end
    end
    if data.gameId=="LOA" then
        local st=data.stats
        local function int(v,a,b) return type(v)=="number" and v%1==0 and v>=a and v<=b end
        if data.ruleVersion~=2 or data.score~=0 or type(st)~="table" or not int(st.aiCount,1,3)
            or data.difficulty~="ai_"..st.aiCount or not int(st.humanColor,1,4) or not int(st.startColor,1,4)
            or not int(st.figuresHome,0,4) or (data.result=="WIN")~=(st.figuresHome==4) then return false end
        if old then for _,k in ipairs({"aiCount","humanColor","startColor","figuresHome"}) do
            if old.personalStats[k]~=st[k] then return false end
        end end
        data.skipHighscores=true
    end
    if goblin then
        local st=data.stats
        local function int(n) return type(n)=="number" and n>=0 and n<math.huge and n%1==0 end
        if data.ruleVersion~=2 or not int(data.score) or type(st)~="table" or type(data.legacyContinuation)~="boolean"
            or not int(data.legacyScore) or not data.legacyContinuation and data.legacyScore~=0
            or data.closed~=(data.result~="STATS") or type(data.levelPerformances)~="table" then return false end
        for _,key in ipairs({"walls","enemies","powerups","maxChain","levelReached","clearedLevel","stagesCleared"}) do
            if not int(st[key]) or old and (st[key]<old.personalStats[key] or old.closed and st[key]~=old.personalStats[key]) then return false end
        end
        if st.levelReached<1 or st.levelReached>12 or st.clearedLevel>st.levelReached or st.stagesCleared>st.clearedLevel
            or not data.legacyContinuation and st.stagesCleared~=st.clearedLevel
            or data.result=="STATS" and (st.clearedLevel~=st.levelReached or st.clearedLevel>=12)
            or data.result=="WIN" and st.clearedLevel~=12 or data.result=="LOSS" and st.clearedLevel>=12
            or old and (data.score<old.score or old.closed and data.score~=old.score
                or old.legacyContinuation~=data.legacyContinuation or old.legacyScore~=data.legacyScore) then return false end
        if #data.levelPerformances~=st.stagesCleared then return false end
        for i=1,st.stagesCleared do if type(data.levelPerformances[i])~="table" then return false end end
        local earnedScore=0
        for key,perf in pairs(data.levelPerformances) do
            if not int(key) or key<1 or key>st.stagesCleared or type(perf)~="table" or perf.id~=key
                or not int(perf.level) or perf.level<1 or perf.level>st.clearedLevel
                or perf.level~=st.clearedLevel-st.stagesCleared+key
                or not int(perf.score) or perf.score>data.score or not int(perf.elapsedMs) then return false end
            local prev=old and old.levelPerformances[key]
            if prev and (prev.level~=perf.level or prev.score~=perf.score or prev.elapsedMs~=perf.elapsedMs) then return false end
            earnedScore=earnedScore+perf.score
        end
        if earnedScore>data.score or data.result~="LOSS" and earnedScore~=data.score then return false end
    end
    if breaker then
        local st=data.stats
        local function integer(n) return type(n)=="number" and n>=0 and n<math.huge and n%1==0 end
        if data.ruleVersion~=2 or data.layoutVersion~=2 or not integer(data.score) or type(st)~="table"
            or type(data.closed)~="boolean" or type(data.legacyCompleted)~="boolean" then return false end
        for _,key in ipairs({"levelReached","maxCombo","clearedLevel","stagesCleared","regularCleared"}) do
            if not integer(st[key]) or old and (st[key]<old.personalStats[key] or old.closed and st[key]~=old.personalStats[key]) then return false end
        end
        if st.levelReached<1 or st.clearedLevel>st.levelReached or st.regularCleared>100 or st.regularCleared>st.stagesCleared
            or data.result=="WIN" and st.regularCleared~=100
            or data.result=="LOSS" and (st.regularCleared==100 or not data.closed or data.legacyCompleted)
            or data.result=="STATS" and data.closed and not data.legacyCompleted
            or old and (data.score<old.score or old.closed and (not data.closed or data.score~=old.score)) then return false end
        local perf=data.levelPerformance
        if perf then
            if type(perf)~="table" or not integer(perf.id) or perf.id<1 or not integer(perf.level) or perf.level<1
                or perf.level>st.clearedLevel or not integer(perf.score) or perf.score>data.score or not integer(perf.elapsedMs) then return false end
            if old and old.levelPerformance then
                local previous=old.levelPerformance
                if perf.id<previous.id or perf.id==previous.id and (perf.score~=previous.score or perf.level~=previous.level or perf.elapsedMs~=previous.elapsedMs) then return false end
            end
        elseif old and old.levelPerformance then return false end
    end
    if orbit then
        local st=data.stats
        if data.ruleVersion~=2 or data.gameMode~="levels" and data.gameMode~="endless"
            or not A.AOD_Logic.DIFFICULTY_DEFS[data.aiDifficulty]
            or data.difficulty~=data.gameMode.."_"..data.aiDifficulty or type(st)~="table"
            or data.score%1~=0 or data.closed~=(data.result~="STATS") then return false end
        for _,key in ipairs({"meteorsKilled","huntersKilled","clearedWave","clearedLevel","stagesCleared","hardLevelsCleared","bombLevelsCleared"}) do
            local n=st[key]
            if type(n)~="number" or n<0 or n==math.huge or n%1~=0
                or old and (n<old.personalStats[key] or old.closed and n~=old.personalStats[key]) then return false end
        end
        if st.clearedLevel>30 or st.hardLevelsCleared>st.stagesCleared or st.bombLevelsCleared>st.stagesCleared
            or data.gameMode=="levels" and st.clearedWave~=0
            or data.gameMode=="endless" and (st.clearedLevel~=0 or st.hardLevelsCleared~=0 or st.bombLevelsCleared~=0)
            or data.result=="WIN" and (data.gameMode~="levels" or st.clearedLevel~=30)
            or old and (data.score<old.score or old.closed and (not data.closed or data.score~=old.score)) then return false end
    end
    if alien then
        local st = data.stats
        local function integer(n) return type(n)=="number" and n>=0 and n<math.huge and n==math.floor(n) end
        if data.ruleVersion~=2 or not integer(data.score) or type(st)~="table"
            or not integer(st.clearedWave) or not integer(st.wavesCleared) or not integer(st.enemiesKilled)
            or data.result=="WIN" and st.clearedWave<30
            or data.result=="LOSS" and (st.clearedWave>=30 or data.closed~=true)
            or old and (data.score<old.score or st.clearedWave<old.clearedWave
                or st.enemiesKilled<old.enemiesKilled
                or st.wavesCleared<old.wavesCleared
                or old.closed and (data.closed~=true or data.score~=old.score or st.clearedWave~=old.clearedWave or st.wavesCleared~=old.wavesCleared or st.enemiesKilled~=old.enemiesKilled)) then return false end
    end
    if data.gameId=="SUDOKU" and (data.result~="WIN" or data.score~=A.SDK_Logic:GetScore(data.difficulty)) then return false end
    if data.gameId == "MINESWEEPER" then
        if type(data.elapsedMs)~="number" or data.elapsedMs~=math.floor(data.elapsedMs)
            or data.elapsedMs<0 or data.elapsedMs>2147483647 then return false end
        if old and (old.elapsedMs~=data.elapsedMs or old.score~=data.score) then return false end
    end
    if data.gameId=="BLACKJACK" then
        local function units(n) return type(n)=="number" and n==math.floor(n) and n>=0 and n<=2147483647 end
        if data.difficulty~="table" or data.score~=0 or type(data.tableId)~="string"
            or not units(data.roundNo) or data.roundNo<1 or not units(data.finalChips2)
            or not units(data.startChips2) or not units(data.stake2) or not units(data.return2)
            or type(data.net2)~="number" or data.net2~=data.return2-data.stake2
            or data.finalChips2~=data.startChips2+data.net2 or not data.stats
            or data.stats.finalChips~=data.finalChips2/2 or not units(data.stats.blackjacks) or data.stats.blackjacks>1
            or data.result~=(data.net2>0 and "WIN" or data.net2<0 and "LOSS" or "DRAW") then return false end
        if old and (old.finalChips2~=data.finalChips2 or old.net2~=data.net2 or old.tableId~=data.tableId
            or old.roundNo~=data.roundNo or old.blackjacks~=data.stats.blackjacks
            or old.stake2~=data.stake2 or old.return2~=data.return2 or old.startChips2~=data.startChips2) then return false end
    end
    if data.gameId=="HIGHERORLOWER" then
        local function units(n) return type(n)=="number" and n==math.floor(n) and n>=0 and n<=2147483647 end
        if data.score~=0 or type(data.tableId)~="string" or not units(data.roundNo) or data.roundNo<1
            or not units(data.finalChips2) or not units(data.startChips2) or not units(data.stake2)
            or data.stake2<50 or data.stake2%50~=0 or not units(data.return2)
            or not units(data.roundBest) or data.roundBest>53 or type(data.net2)~="number"
            or data.net2~=data.return2-data.stake2 or data.finalChips2~=data.startChips2+data.net2
            or type(data.stats)~="table" or data.stats.finalChips~=data.finalChips2/2 or data.stats.maxStreak~=data.roundBest
            or (data.reason~="LOSS" and data.reason~="CASHOUT" and data.reason~="DECK_EMPTY")
            or data.stats.cashouts~=(data.reason~="LOSS" and data.roundBest>0 and 1 or 0)
            or data.result~=(data.net2>0 and "WIN" or data.net2<0 and "LOSS" or "DRAW") then return false end
        local expected=data.reason=="LOSS" and 0 or (data.roundBest>0 and A.HOL_Logic:CalcCashOut(data.stake2,data.roundBest,data.difficulty) or data.stake2)
        if data.return2~=expected or data.reason=="CASHOUT" and data.roundBest==0 then return false end
        if old and (old.finalChips2~=data.finalChips2 or old.net2~=data.net2 or old.tableId~=data.tableId
            or old.roundNo~=data.roundNo or old.roundBest~=data.roundBest or old.stake2~=data.stake2
            or old.return2~=data.return2 or old.startChips2~=data.startChips2 or old.reason~=data.reason) then return false end
    end
    if data.gameId=="SOLITAIRE" then
        if not A.SOL_Logic:IsMode(data.difficulty) then return false end
        local function integer(n) return type(n)=="number" and n==math.floor(n) and n>=0 and n<=2147483647 end
        if not integer(data.score) or not integer(data.elapsedMs) or not integer(data.undoUsed) or not integer(data.wastePass) or data.wastePass<1
            or data.skipHighscores~=true or (data.scoreVersion~=1 and data.scoreVersion~=2)
            or data.scoreVersion==2 and (data.score>745 or data.newScore~=data.score)
            or data.scoreVersion==1 and data.newScore~=nil then return false end
        if old and (old.score~=data.score or old.elapsedMs~=data.elapsedMs or old.undoUsed~=data.undoUsed
            or old.wastePass~=data.wastePass or old.scoreVersion~=data.scoreVersion) then return false end
    end
    if data.gameId=="TAVERNCARDS" then
        if not A.TC_Logic:IsDifficulty(tostring(data.difficulty):sub(6)) or data.score~=0 or type(data.stats)~="table"
            or data.gameMode~="single" and data.gameMode~="multi" or type(data.roundsPlayed)~="number" or data.roundsPlayed<0 or data.roundsPlayed~=math.floor(data.roundsPlayed) then return false end
        for _,key in ipairs({"unosCalled","wild4Played","unosMissed","unosCaught"}) do
            local n=data.stats[key] or 0
            if type(n)~="number" or n<0 or n~=math.floor(n) or n>2147483647 or old and (old.personalStats[key] or 0)~=n then return false end
        end
        if old and (old.roundsPlayed~=data.roundsPlayed or old.gameMode~=data.gameMode) then return false end
    end
    if data.gameId=="TICTACTOE" then
        local st=data.stats
        if type(st)~="table" then return false end
        local cfg=A.TicTacToeLogic.NormalizeConfig({boardSize=st.boardSize,winLength=st.winLength,aiDifficulty=data.aiDifficulty})
        local expected=data.result=="WIN" and ({easy=100,normal=150,hard=200})[data.aiDifficulty] or data.result=="DRAW" and 50 or 0
        if not cfg or data.difficulty~=A.TicTacToeLogic.Variant(cfg) or data.ruleVersion~=2
            or data.skipHighscores~=true or data.score~=expected or st.vsHuman~=0
            or not A.TicTacToeLogic.IsInteger(st.moveCount) or st.moveCount<1 or st.moveCount>st.boardSize^2
            or not A.TicTacToeLogic.IsInteger(st.seriesStreak) or st.seriesStreak<0
            or st.startedAs~=1 and st.startedAs~=2 or st.seriesWin~=0 and st.seriesWin~=1
            or st.seriesWin==1 and data.result~="WIN" then return false end
        if old then
            if old.score~=data.score then return false end
            for _,key in ipairs({"boardSize","winLength","moveCount","seriesStreak","seriesWin","startedAs","vsHuman"}) do
                if old.personalStats[key]~=st[key] then return false end
            end
        end
    end
    if data.gameId=="WHACKAMOLE" then
        local st=data.stats
        local function integer(n) return type(n)=="number" and n>=0 and n<=2147483647 and n==math.floor(n) end
        local points=({easy=10,normal=15,hard=25})[data.difficulty]
        if data.ruleVersion~=2 or type(st)~="table" or not points
            or not integer(st.hitCount) or not integer(st.missed) or data.score~=st.hitCount*points
            or data.reason~="TIME" and data.reason~="BOMB"
            or data.result~=(data.reason=="TIME" and "WIN" or "LOSS") then return false end
        if old and (old.score~=data.score or old.reason~=data.reason
            or old.personalStats.hitCount~=st.hitCount or old.personalStats.missed~=st.missed) then return false end
    end
    if data.gameId=="REACTIONSTRIKE" then
        local ms=data.reactionMs
        if data.ruleVersion~=2 or data.skipHighscores~=true then return false end
        if data.result=="WIN" then
            if type(ms)~="number" or ms~=math.floor(ms) or ms<0 or ms>2147483647
                or data.score~=A.RS_Logic:CalcScore(ms,data.difficulty) or data.reason~="STRIKE" then return false end
        elseif ms~=nil or data.score~=0 or data.reason~="EARLYCLICK" and data.reason~="FAKEOUT" then return false end
        if old and (old.reactionMs~=ms or old.score~=data.score or old.reason~=data.reason) then return false end
    end
    if data.gameId=="ARCADIASECHO" then
        if data.result~="LOSS" or data.ruleVersion~=2 or data.score~=math.floor(data.score)
            or type(data.stats)~="table" or data.stats.maxSequence~=data.score
            or (data.reason~="error" and data.reason~="exit" and data.reason~="hide" and data.reason~="restart")
            or old and old.score~=data.score then return false end
    end
    if data.gameId=="BARREL_BRAWL" then
        local st=data.stats
        local function int(n) return type(n)=="number" and n>=0 and n<math.huge and n%1==0 end
        if data.ruleVersion~=2 or not int(data.score) or not int(data.elapsedMs) or type(st)~="table"
            or not int(st.levelReached) or st.levelReached<1 or not int(st.rescues) or not int(st.barrelsJumped)
            or data.result~=(st.rescues>0 and "WIN" or "LOSS")
            or data.reason~="BARREL" and data.reason~="FALL" and data.reason~="TIMEOUT" then return false end
        if old then
            if old.score~=data.score or old.reason~=data.reason or old.elapsedMs~=data.elapsedMs then return false end
            for _,key in ipairs({"levelReached","rescues","barrelsJumped"}) do if old.personalStats[key]~=st[key] then return false end end
        end
    end
    if data.gameId=="SHELLGAME" then
        local L=A.SHG_Logic
        if data.ruleVersion~=2 or data.score~=0 or not L:IsDifficulty(tostring(data.difficulty):sub(7))
            or type(data.tableId)~="string" or not self:GetSerial("SHELLGAME",data.tableId)
            or not L:IsUnits(data.roundNo) or data.roundNo<1 or not L:IsUnits(data.finalChips2)
            or not L:IsUnits(data.startChips2) or not L:IsUnits(data.stake2) or data.stake2<50 or data.stake2%50~=0
            or data.startChips2<data.stake2 or not L:IsUnits(data.return2) or data.net2~=data.return2-data.stake2
            or data.finalChips2~=data.startChips2+data.net2 or type(data.stats)~="table"
            or data.stats.finalChips~=data.finalChips2/2 or data.stats.roundsPlayed~=1
            or data.result~=(data.net2>0 and "WIN" or "LOSS") or data.stats.roundsWon~=(data.result=="WIN" and 1 or 0)
            or data.stats.roundsLost~=(data.result=="LOSS" and 1 or 0) or data.reason~="GUESS" and data.reason~="ABORT" then return false end
        local expected=data.result=="WIN" and data.stake2*(1+L.DIFFICULTY[data.difficulty:sub(7)].payout) or 0
        if data.return2~=expected or data.reason=="ABORT" and data.result~="LOSS" then return false end
        if old and (old.tableId~=data.tableId or old.roundNo~=data.roundNo or old.finalChips2~=data.finalChips2
            or old.startChips2~=data.startChips2 or old.stake2~=data.stake2 or old.return2~=data.return2 or old.reason~=data.reason) then return false end
    end
    if data.gameId=="BUBBLESHOOTER" then
        local function integer(n) return type(n)=="number" and n>=0 and n<=2147483647 and n==math.floor(n) end
        local st=data.stats
        if data.ruleVersion~=3 or data.playMode~="shot" and data.playMode~="endless" and data.playMode~="time"
            or data.difficulty~=A.BS_Logic.ScoreKey(data.playMode,data.aiDifficulty)
            or data.aiDifficulty~="easy" and data.aiDifficulty~="normal" and data.aiDifficulty~="hard"
            or type(st)~="table" or not integer(data.score) or not integer(st.shotsUsed) or st.shotsUsed<1
            or not integer(st.maxCombo) or not integer(st.maxDrop) or not integer(st.powerUsed)
            or not integer(st.overchargeCount) then return false end
        if data.playMode=="shot" and (not integer(data.slot) or data.slot<1 or data.slot>3
            or not integer(data.levelIndex) or data.levelIndex<1 or data.levelIndex>100
            or not integer(data.stars) or data.result=="WIN" and (data.stars<1 or data.stars>3)) then return false end
        if data.result=="LOSS" and data.stars~=0 then return false end
        if old then
            if old.score~=data.score or old.levelIndex~=data.levelIndex or old.slot~=data.slot or old.stars~=data.stars then return false end
            for _,key in ipairs({"shotsUsed","maxCombo","maxDrop","powerUsed","overchargeCount"}) do
                if old.personalStats[key]~=st[key] then return false end
            end
        end
    end
    if data.gameId=="HANGMAN" and not A.HGM_Settings:ValidateResult(data,old) then return false end
    if data.recordPlayed == false and not old then return false end
    local original, staged, work = _G.ArcadiaNexusDB, {}, Copy(data)
    for k, v in pairs(original) do staged[k] = v end
    for _, k in ipairs(ROOTS) do staged[k] = Copy(original[k]) end
    if data.gameId=="BUBBLESHOOTER" or orbit or data.gameId=="ALCHEMISTSSORT" or data.gameId=="MOSAICOFAZEROTH" or data.gameId=="NONOGRAM" or data.gameId=="SHADOWSCONQUEST" or data.gameId=="HANGMAN" then
        staged.gameSettings={}
        for k,v in pairs(original.gameSettings or {}) do staged.gameSettings[k]=v end
        staged.gameSettings[data.gameId]=Copy((original.gameSettings or {})[data.gameId] or {})
    end
    work.recordPlayed, work.localReplay = not old, old ~= nil
    local reward = not old
    if alien then
        reward = data.result ~= "STATS" and (not old or old.result == "STATS")
        work.recordPlayed, work.localReplay = reward, not reward
        work.killDelta = data.stats.enemiesKilled - (old and old.enemiesKilled or 0)
        work.wavesDelta = data.stats.wavesCleared - (old and old.wavesCleared or 0)
    end
    if breaker or goblin then
        reward=data.result~="STATS" and (not old or old.result=="STATS")
        work.recordPlayed,work.localReplay=reward,not reward
        work.stagesDelta=data.stats.stagesCleared-(old and old.personalStats.stagesCleared or 0)
    end
    if orbit then
        reward=data.result~="STATS" and (not old or old.result=="STATS")
        work.recordPlayed,work.localReplay=reward,not reward
        local prev=old and old.personalStats or {}
        work.meteorDelta=data.stats.meteorsKilled-(prev.meteorsKilled or 0)
        work.hunterDelta=data.stats.huntersKilled-(prev.huntersKilled or 0)
        work.stagesDelta=data.stats.stagesCleared-(prev.stagesCleared or 0)
    end
    local beforeXP = original.profile and original.profile.totalXP or 0
    local beforeGold = original.tavernGold and original.tavernGold.balance or 0
    self._events, self._preparing = {}, true
    _G.ArcadiaNexusDB = staged
    local ok, err = pcall(function()
        local function Step(module)
            assert(module and module.HandleGameResult, "Missing local result step")
            module:HandleGameResult(work)
        end
        if work.gameId=="BUBBLESHOOTER" then A.BS_Settings:ApplyResult(work) end
        if orbit then A.AOD_Settings:ApplyResult(work) end
        if work.gameId=="ALCHEMISTSSORT" and not old then A.ALS_Settings:ApplyResult(work) end
        if work.gameId=="MOSAICOFAZEROTH" and not old then A.SLP_Settings:ApplyResult(work) end
        if work.gameId=="NONOGRAM" and not old then A.NON_Settings:ApplyResult(work) end
        if work.gameId=="SHADOWSCONQUEST" and not old then A.SC_Settings:ApplyResult(work) end
        if work.gameId=="HANGMAN" and not old then A.HGM_Settings:ApplyResult(work) end
        Step(A.ScoreManager)
        if work.gameId=="MOSAICOFAZEROTH" then work.difficulty=work.stats.difficulty end
        if work.gameId=="NONOGRAM" then work.difficulty=work.stats.difficulty end
        if work.gameId=="SHADOWSCONQUEST" then work.difficulty=work.stats.difficulty end
        -- Tavern Cards' new W/L buckets do not redefine gameplay difficulty or rewards.
        if work.gameId=="TAVERNCARDS" then work.difficulty=work.difficulty:sub(6) end
        if work.gameId=="SHELLGAME" then work.difficulty=work.difficulty:sub(7) end
        -- LOA historically supplied no difficulty: keep its 1.0 reward multiplier.
        if work.gameId=="LOA" then work.difficulty=nil end
        if work.gameId=="TICTACTOE" or work.gameId=="BUBBLESHOOTER" or orbit then work.difficulty=work.aiDifficulty end
        if reward then Step(A.XPManager) end
        if reward then Step(A.AchievementManager)
        elseif alien then A.AchievementManager:HandleAlienDefenseProgress(work)
        elseif orbit then A.AchievementManager:HandleOrbitProgress(work)
        elseif breaker then A.AchievementManager:HandleBlockBreakerProgress(work)
        elseif goblin then A.AchievementManager:HandleGoblinBlastProgress(work) end
        if reward then Step(A.ChallengeManager); Step(A.StreakManager) end
        self:GetJournal().receipts[data.runId] = old and Copy(old) or {
            serial = serial, gameId = data.gameId, difficulty = data.difficulty,
            result = data.result, timestamp = GetServerTime(),
            score = data.gameId ~= "2048" and data.score or nil,
            levelIndex=data.gameId=="BUBBLESHOOTER" and data.levelIndex or nil,
            slot=data.gameId=="BUBBLESHOOTER" and data.slot or nil,
            stars=data.gameId=="BUBBLESHOOTER" and data.stars or nil,
            elapsedMs = (data.gameId == "MINESWEEPER" or data.gameId=="SOLITAIRE" or data.gameId=="BARREL_BRAWL") and data.elapsedMs or nil,
            reactionMs=data.gameId=="REACTIONSTRIKE" and data.reactionMs or nil,
            legacyContinuation=data.gameId=="BLOCKDROP" and data.legacyContinuation or nil,
            scoreVersion=data.gameId=="SOLITAIRE" and data.scoreVersion or nil,
            undoUsed=data.gameId=="SOLITAIRE" and data.undoUsed or nil,
            wastePass=data.gameId=="SOLITAIRE" and data.wastePass or nil,
            personalStats=(data.gameId=="TAVERNCARDS" or data.gameId=="TICTACTOE" or data.gameId=="WHACKAMOLE" or data.gameId=="BUBBLESHOOTER" or data.gameId=="BARREL_BRAWL" or data.gameId=="BLOCKDROP" or data.gameId=="DARKMOON_PINBALL" or data.gameId=="SNAKE" or data.gameId=="AZEROTHCONQUEST" or data.gameId=="BACKGAMMON" or data.gameId=="LOA" or data.gameId=="GALLYWIX") and Copy(data.stats) or nil,
            roundsPlayed=data.gameId=="TAVERNCARDS" and data.roundsPlayed or nil,
            gameMode=data.gameId=="TAVERNCARDS" and data.gameMode or nil,
            tableId=(data.gameId=="BLACKJACK" or data.gameId=="HIGHERORLOWER" or data.gameId=="SHELLGAME") and data.tableId or nil,
            roundNo=(data.gameId=="BLACKJACK" or data.gameId=="HIGHERORLOWER" or data.gameId=="SHELLGAME") and data.roundNo or nil,
            finalChips2=(data.gameId=="BLACKJACK" or data.gameId=="HIGHERORLOWER" or data.gameId=="SHELLGAME") and data.finalChips2 or nil,
            net2=(data.gameId=="BLACKJACK" or data.gameId=="HIGHERORLOWER" or data.gameId=="SHELLGAME") and data.net2 or nil,
            roundBest=data.gameId=="HIGHERORLOWER" and data.roundBest or nil,
            reason=(data.gameId=="HIGHERORLOWER" or data.gameId=="SHELLGAME" or data.gameId=="REACTIONSTRIKE" or data.gameId=="WHACKAMOLE" or data.gameId=="BARREL_BRAWL") and data.reason or nil,
            blackjacks=data.gameId=="BLACKJACK" and data.stats.blackjacks or nil,
            stake2=(data.gameId=="BLACKJACK" or data.gameId=="HIGHERORLOWER" or data.gameId=="SHELLGAME") and data.stake2 or nil,
            return2=(data.gameId=="BLACKJACK" or data.gameId=="HIGHERORLOWER" or data.gameId=="SHELLGAME") and data.return2 or nil,
            startChips2=(data.gameId=="BLACKJACK" or data.gameId=="HIGHERORLOWER" or data.gameId=="SHELLGAME") and data.startChips2 or nil,
        }
        if alien then
            local receipt = self:GetJournal().receipts[data.runId]
            receipt.result, receipt.score = data.result, data.score
            receipt.clearedWave, receipt.enemiesKilled = data.stats.clearedWave, data.stats.enemiesKilled
            receipt.wavesCleared = data.stats.wavesCleared
            receipt.closed = data.closed == true
        end
        if orbit then
            local receipt=self:GetJournal().receipts[data.runId]
            receipt.result,receipt.score,receipt.closed=data.result,data.score,data.closed
            receipt.personalStats=Copy(data.stats)
        end
        if data.gameId=="BLOCKDROP" then self:GetJournal().receipts[data.runId].legacyContinuation=data.legacyContinuation end
        if goblin then
            local receipt=self:GetJournal().receipts[data.runId]
            receipt.result,receipt.score,receipt.closed=data.result,data.score,data.closed
            receipt.personalStats=Copy(data.stats); receipt.levelPerformances=Copy(data.levelPerformances)
            receipt.legacyContinuation,receipt.legacyScore=data.legacyContinuation,data.legacyScore
        end
        if breaker then
            local receipt=self:GetJournal().receipts[data.runId]
            receipt.result,receipt.score,receipt.closed=data.result,data.score,data.closed
            receipt.personalStats=Copy(data.stats); receipt.levelPerformance=Copy(data.levelPerformance)
            receipt.legacyCompleted=data.legacyCompleted
        end
        if data.gameId=="ALCHEMISTSSORT" then
            local receipt=self:GetJournal().receipts[data.runId]
            receipt.alsFacts=Copy(data)
            receipt.alsXP=old and old.alsXP or math.max(0,(staged.profile and staged.profile.totalXP or 0)-beforeXP)
            receipt.alsGold=old and old.alsGold or ((staged.tavernGold and staged.tavernGold.balance or 0)-beforeGold)
            if not old then
                receipt.alsRating={bestStars=work.bestStars,starsImproved=work.starsImproved,starsGained=work.starsGained,
                    newMetricRecords=Copy(work.newMetricRecords)}
            end
        end
        if data.gameId=="MOSAICOFAZEROTH" then
            local receipt=self:GetJournal().receipts[data.runId]
            receipt.mosaicFacts=Copy(data)
            receipt.mosaicXP=old and old.mosaicXP or math.max(0,(staged.profile and staged.profile.totalXP or 0)-beforeXP)
            receipt.mosaicGold=old and old.mosaicGold or ((staged.tavernGold and staged.tavernGold.balance or 0)-beforeGold)
            if not old then receipt.mosaicRecords=Copy(work.newMetricRecords) end
        end
        if data.gameId=='NONOGRAM' then
            local receipt=self:GetJournal().receipts[data.runId]
            receipt.nonFacts=Copy(data)
            if not old then receipt.nonXP=math.max(0,(staged.profile and staged.profile.totalXP or 0)-beforeXP); receipt.nonGold=(staged.tavernGold and staged.tavernGold.balance or 0)-beforeGold; receipt.nonTimeRecord=work.newTimeRecord; receipt.nonHighscore=work.newHighscore end
        end
        if data.gameId=="SHADOWSCONQUEST" then
            local receipt=self:GetReceipt(data.runId); receipt.scFacts=Copy(data)
            if not old then receipt.scXP=math.max(0,(staged.profile and staged.profile.totalXP or 0)-beforeXP); receipt.scGold=(staged.tavernGold and staged.tavernGold.balance or 0)-beforeGold
                receipt.scRating={bestStars=work.bestStars,starsImproved=work.starsImproved,starsGained=work.starsGained,newMoveRecord=work.newMoveRecord,campaignCompleted=work.campaignCompleted,newHighscore=work.newHighscore} end
        end
        if data.gameId=="HANGMAN" then
            local receipt=self:GetReceipt(data.runId); receipt.hgmFacts=Copy(data)
            if not old then receipt.hgmXP=math.max(0,(staged.profile and staged.profile.totalXP or 0)-beforeXP); receipt.hgmGold=(staged.tavernGold and staged.tavernGold.balance or 0)-beforeGold end
        end
        self:GetJournal().issued[data.runId] = nil
    end)
    _G.ArcadiaNexusDB = original
    self._preparing = false
    local events = self._events
    self._events = nil
    if not ok then
        data.processingFailed = true
        GH_LogError("LocalResults", tostring(err))
        return false
    end
    for _, k in ipairs(ROOTS) do
        if type(original[k]) == "table" and type(staged[k]) == "table" then Commit(original[k], staged[k])
        else original[k] = staged[k] end
    end
    if data.gameId=="BUBBLESHOOTER" or orbit or data.gameId=="ALCHEMISTSSORT" or data.gameId=="MOSAICOFAZEROTH" or data.gameId=="NONOGRAM" or data.gameId=="SHADOWSCONQUEST" or data.gameId=="HANGMAN" then
        original.gameSettings=original.gameSettings or {}
        original.gameSettings[data.gameId]=original.gameSettings[data.gameId] or {}
        Commit(original.gameSettings[data.gameId],staged.gameSettings[data.gameId])
    end
    data.processingFailed = nil
    data.newHighscore, data.localReplay = work.newHighscore, work.localReplay
    if data.gameId=="NONOGRAM" then
        local receipt=self:GetReceipt(data.runId)
        data.newHighscore=receipt.nonHighscore; data.newTimeRecord=receipt.nonTimeRecord
    end
    data.newMetricRecords = work.newMetricRecords
    data.awardedXP = math.max(0, (staged.profile and staged.profile.totalXP or 0) - beforeXP)
    data.awardedGold = (staged.tavernGold and staged.tavernGold.balance or 0) - beforeGold
    if data.gameId=="ALCHEMISTSSORT" then
        local resultReceipt=self:GetReceipt(data.runId)
        data.awardedXP,data.awardedGold=resultReceipt.alsXP,resultReceipt.alsGold
        local rating=resultReceipt.alsRating
        data.bestStars,data.starsImproved,data.starsGained=rating.bestStars,rating.starsImproved,rating.starsGained
        data.newMetricRecords=Copy(rating.newMetricRecords)
    end
    if data.gameId=="SHADOWSCONQUEST" then
        local receipt=self:GetReceipt(data.runId); data.awardedXP,data.awardedGold=receipt.scXP,receipt.scGold
        for k,v in pairs(receipt.scRating) do data[k]=v end
    end
    if data.gameId=="HANGMAN" then
        local receipt=self:GetReceipt(data.runId); data.awardedXP,data.awardedGold=receipt.hgmXP,receipt.hgmGold
    end
    data.processed = true
    if data.gameId=="NONOGRAM" then
        local receipt=self:GetReceipt(data.runId); data.awardedXP,data.awardedGold=receipt.nonXP,receipt.nonGold
    end
    if data.gameId=="MOSAICOFAZEROTH" then
        local receipt=self:GetReceipt(data.runId)
        data.awardedXP,data.awardedGold=receipt.mosaicXP,receipt.mosaicGold
        data.newMetricRecords=Copy(receipt.mosaicRecords)
    end
    self._publishing = true
    for _, item in ipairs(events) do
        local notified, message = pcall(A.Engine.Emit, A.Engine, item.event, unpack(item.args, 1, item.n))
        if not notified then GH_LogError("LocalResults", "Notification: " .. tostring(message)) end
        if item.event == "GOLD_UPDATED" and A.ToastManager and A.ToastManager.ShowGold then
            local gold = item.args[1]
            pcall(A.ToastManager.ShowGold, A.ToastManager, gold.delta, gold.reason)
        end
    end
    self._publishing = false
    -- After commit, receipt reads and notification. A cleanup error cannot revoke the booking.
    local cleaned, cleanErr = pcall(function()
        local journal = self:GetJournal()
        local cutoff = math.max(0, journal.serial - 256)
        if cutoff > journal.retiredThrough then self:Prune(data.runId) end
    end)
    if not cleaned then
        pcall(function()
            GH_LogError("LocalResults", tostring(cleanErr))
        end)
    end
    return true
end
