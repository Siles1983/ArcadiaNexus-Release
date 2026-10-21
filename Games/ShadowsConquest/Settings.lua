-- Campaign books are independent of preserved legacy settings and leaderboard data.
local A=ArcadiaNexus
local S={MAX_SLOTS=3,Defaults={difficulty='easy',moveLimitActive=false,soundEnabled=true,soundOnToggle=true,soundOnWin=true,soundOnLose=true}}
A.SC_Settings=S
local function L() return A.SC_Logic end
local function DB() return A.Persistence:GetGameSettings('SHADOWSCONQUEST') end
local function Data() local db=DB(); db.slots=db.slots or {}; db.pendingResults=db.pendingResults or {}; db.modern=db.modern or {version=2,played=0,wins=0,losses=0,uniqueOptimal={}}; return db end
function S:Get(k) local v=DB()[k]; if v~=nil then return v end return self.Defaults[k] end
function S:Set(k,v)
 if (k=='difficulty' or k=='moveLimitActive') and A.SC_Engine and A.SC_Engine:IsConfigLocked() then return false end
 if k=='difficulty' and not L().DiffConfig[v] or k=='moveLimitActive' and type(v)~='boolean' then return false end A.Persistence:SetGameSetting('SHADOWSCONQUEST',k,v); return true
end
function S:Reset() for k,v in pairs(self.Defaults) do self:Set(k,v) end end
function S:GetAll() local r={} for k in pairs(self.Defaults) do r[k]=self:Get(k) end return r end
-- Historical API stays readable; modern runs never advance these counters.
function S:GetPuzzleIndex(d) return type(DB().puzzleIndex)=='table' and DB().puzzleIndex[d] or 1 end
function S:SetPuzzleIndex(d,i) local db=DB(); db.puzzleIndex=db.puzzleIndex or {}; db.puzzleIndex[d]=i end
function S:GetPuzzlesSolved() return DB().puzzlesSolved or 0 end
function S:IncrementPuzzlesSolved() local db=DB(); db.puzzlesSolved=(db.puzzlesSolved or 0)+1 end
function S:LoadSlot(i) if not L():Int(i,3) or i<1 then return nil end return Data().slots[i] end
function S:SaveSlot(i,b) Data().slots[i]=L():Copy(b) end
function S:GetPending(i) for _,d in pairs(Data().pendingResults) do if type(d)=='table' and (i==nil or d.slot==i) then return d end end end
function S:DeleteSlot(i) if self:GetPending() then return false end if not L():Int(i,3) or i<1 then return false end Data().slots[i]=nil; return true end
function S:QueueResult(d) Data().pendingResults[d.runId]=L():Copy(d) end
function S:RecordStart() local st=Data().modern; st.played=st.played+1 end
function S:NewBook(i,d,limit)
 if not L():Int(i,3) or i<1 or not L().DiffConfig[d] or type(limit)~='boolean' then return nil end
 local b={slotVersion=1,ruleVersion=2,catalogVersion=2,ratingVersion=2,scoreVersion=2,slot=i,difficulty=d,moveLimitActive=limit,campaignVersion=1,currentLevel=1,clearedLevel=0,stars={},bests={},legacyUnlocked={},mapLevel=1}
 local db=DB(); local legacy=type(db.puzzleIndex)=='table' and db.puzzleIndex[d]; local count=d=='hard' and 10 or 12
 local evidence=L():Int(legacy,count) and legacy>=1 or L():Int(db.puzzlesSolved) and db.puzzlesSolved>0
 -- Keep old published puzzles selectable, but never jump the new-campaign cursor
 -- onto a remapped catalog index (those sit on later map pages after minimum-sort).
 if evidence then for level,e in ipairs(A.SC_Catalog[d]) do if e.legacyIndex then b.legacyUnlocked[level]=true end end end
 return b
end
function S:IsUnlocked(b,i) return L():Int(i,50) and i>=1 and (A.CampaignProgress.IsLevelUnlocked(b,i,{levelCount=50}) or b.legacyUnlocked[i]==true) or false end
function S:Completed(b) for i=1,50 do if A.CampaignProgress.GetStars(b,i)<1 then return false end end return true end
function S:ValidateBook(b,i)
 if type(b)~='table' or b.slotVersion~=1 or b.ruleVersion~=2 or b.catalogVersion~=2 or b.ratingVersion~=2 or b.scoreVersion~=2 or b.slot~=i or not L().DiffConfig[b.difficulty] or type(b.moveLimitActive)~='boolean' or b.campaignVersion~=1 or not L():Int(b.currentLevel,50) or b.currentLevel<1 or not L():Int(b.clearedLevel,50) or not L():Int(b.mapLevel,50) or b.mapLevel<1 or type(b.stars)~='table' or type(b.bests)~='table' or type(b.legacyUnlocked)~='table' then return nil end
 for level,n in pairs(b.stars) do if not L():Int(level,50) or level<1 or not L():Int(n,3) then return nil end end
 local highest=0; for level,n in pairs(b.stars) do if n>0 then highest=math.max(highest,level) end end
 if b.clearedLevel~=highest or b.currentLevel~=math.min(50,highest+1) then return nil end
 for level,best in pairs(b.bests) do local e=L():Entry(b.difficulty,level); if not e or type(best)~='table' or best.puzzleId~=e.id or not L():Int(best.moves) or best.moves<e.optimalMoves or b.moveLimitActive and best.moves>e.moveLimit then return nil end end
 for level,v in pairs(b.legacyUnlocked) do local e=L():Entry(b.difficulty,level); if v~=true or not e or not e.legacyIndex then return nil end end
 if b.inProgress then
  local s=b.inProgress; local gs=L():ValidateState(s.gameState); local serial=A.LocalResults:GetSerial('SHADOWSCONQUEST',s.runId)
  if s.snapshotVersion~=1 or s.runId~=b.runId or not serial or A.LocalResults:GetJournal().issued[s.runId]~=serial or A.LocalResults:GetReceipt(s.runId) or not L():Int(s.revision) or not gs or gs.difficulty~=b.difficulty or gs.moveLimitActive~=b.moveLimitActive or not self:IsUnlocked(b,gs.puzzleIndex) or L():IsWon(gs) or L():IsMoveLimitReached(gs) then return nil end
 elseif b.runId~=nil then return nil end
 return L():Copy(b)
end
local function Facts(d) return {runId=d.runId,slot=d.slot,ruleVersion=d.ruleVersion,catalogVersion=d.catalogVersion,ratingVersion=d.ratingVersion,scoreVersion=d.scoreVersion,difficulty=d.difficulty,result=d.result,reason=d.reason,score=d.score,stars=d.stars,gameState=d.gameState,stats=d.stats} end
function S:ValidateResult(d,old)
 if d.ruleVersion~=2 or d.catalogVersion~=2 or d.ratingVersion~=2 or d.scoreVersion~=2 or not L():Int(d.slot,3) or d.slot<1 then return false end
 local gs=L():ValidateState(d.gameState); if not gs or d.difficulty~=L():ScoreKey(gs.difficulty,gs.moveLimitActive) or type(d.stats)~='table' or d.stats.difficulty~=gs.difficulty or d.stats.moves~=gs.moveCount or d.stats.puzzleId~=gs.puzzleId or d.stats.moveLimitActive~=gs.moveLimitActive then return false end
 if d.result=='WIN' then if not L():IsWon(gs) or d.score~=L():CalcScore(gs) or d.stars~=L():Stars(gs) or d.reason~='solved' then return false end
 elseif d.result=='LOSS' then if not L():IsMoveLimitReached(gs) or L():IsWon(gs) or d.score~=0 or d.stars~=0 or d.reason~='moves' then return false end else return false end
 local frozen=old and old.scFacts or self:GetPending(d.slot)
 if not frozen or not L():Same(Facts(frozen),Facts(d)) then return false end
 if not old then local b=self:ValidateBook(self:LoadSlot(d.slot),d.slot); if not b or not b.inProgress or b.runId~=d.runId or b.difficulty~=gs.difficulty or b.moveLimitActive~=gs.moveLimitActive or b.inProgress.gameState.puzzleId~=gs.puzzleId then return false end end
 return true
end
function S:ApplyResult(d)
 local db=Data(); local st=db.modern; local gs=d.gameState; local b=db.slots[d.slot]
 st[d.result=='WIN' and 'wins' or 'losses']=st[d.result=='WIN' and 'wins' or 'losses']+1
 if d.result=='WIN' then
  d.bestStars,d.starsImproved,d.starsGained=A.CampaignProgress.RecordLevel(b,gs.puzzleIndex,d.stars,{levelCount=50})
  local prev=b.bests[gs.puzzleIndex]; d.newMoveRecord=not prev or gs.moveCount<prev.moves
  if d.newMoveRecord then b.bests[gs.puzzleIndex]={puzzleId=gs.puzzleId,moves=gs.moveCount} end
  if gs.moveCount==gs.puzzleOptimal then st.uniqueOptimal[gs.puzzleId]=true end
  b.mapLevel=math.min(50,gs.puzzleIndex+1)
 end
 b.inProgress=nil; b.runId=nil; b.timestamp=time(); db.pendingResults[d.runId]=nil; d.campaignCompleted=self:Completed(b)
end
