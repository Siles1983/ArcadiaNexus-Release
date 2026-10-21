-- Nether Bound: settings and durable local rounds. Historical fields stay intact.
local A=ArcadiaNexus
local S={}; A.HGM_Settings=S
local defaults={category='all',difficulty='normal',soundEnabled=true,petChoice='random',reducedMotion=false,wins=0,losses=0}
local aliases={alle='all',characters='chars',charaktere='chars',orte='places',waffen='weapons',instances='raids',instanzen='raids',schlachtzuege='raids',klassen='classes',voelker='races',peoples='races',bosse='bosses',fraktionen='factions',kreaturen='creatures',berufe='professions',['völker']='races',['schlachtzüge']='raids'}
local function L() return A.HGM_Logic end
local function Data()
 local db=A.Persistence:GetGameSettings('HANGMAN')
 if db.soundEnabled==nil and db.sound~=nil then db.soundEnabled=db.sound end
 for _,key in ipairs({'pendingResults','wordHistory'}) do
  if type(db[key])~='table' then
   if db[key]~=nil then db.legacyData=db.legacyData or {}; db.legacyData[#db.legacyData+1]={key=key,value=db[key]} end
   db[key]={}
  end
 end
 if type(db.modern)~='table' then db.modern={version=1,played=0,wins=0,losses=0,perfectWins=0} end
 return db,db.modern
end
function S:NormalizeDifficulty(value)
 value=type(value)=='string' and value:lower() or 'normal'
 return L().ERRORS[value] and value or 'normal'
end
function S:NormalizeCategory(value)
 value=type(value)=='string' and value:lower() or 'all'; value=aliases[value] or value
 return A.HGM_Words:IsValidCategory(value) and value or 'all'
end
function S:Get(key)
 local db=Data(); local value=db[key]; if value==nil then value=defaults[key] end
 if key=='category' or key=='difficulty' then
  local E=A.HGM_Engine
  if E and E:IsConfigLocked() and E.board then return key=='category' and E.board.selectedCategory or E.board.difficulty end
  return key=='category' and self:NormalizeCategory(value) or self:NormalizeDifficulty(value)
 end
 return value
end
function S:Set(key,value)
 if key=='category' or key=='difficulty' then
  if A.HGM_Engine and A.HGM_Engine:IsConfigLocked() then return false end
  value=key=='category' and self:NormalizeCategory(value) or self:NormalizeDifficulty(value)
 end
 if key=='petChoice' and A.HGM_Pets and not A.HGM_Pets:IsChoice(value) then return false end
 A.Persistence:SetGameSetting('HANGMAN',key,value); return true
end
function S:GetMaxErrors() return L().ERRORS[self:Get('difficulty')] end
function S:Reset()
 local db=Data(); db.soundEnabled=true; db.petChoice='random'; db.reducedMotion=false
end
function S:GetStats() local _,st=Data(); return st end
function S:GetHistory(locale)
 local db=Data(); local h=db.wordHistory[locale]
 if type(h)~='table' then return {} end
 local out={}; for _,id in ipairs(h) do if A.HGM_Words:GetLocalizedWord(id,locale) then out[#out+1]=id end end
 while #out>20 do table.remove(out,1) end; return out
end
function S:RecordStart(board)
 local db,st=Data(); local h=self:GetHistory(board.locale); h[#h+1]=board.wordId
 while #h>20 do table.remove(h,1) end; db.wordHistory[board.locale]=h; st.played=st.played+1
end
function S:GetPending(slot)
 local db=Data(); local first
 for _,d in pairs(db.pendingResults) do
  if type(d)=='table' and (slot==nil or d.slot==slot) and (not first or tostring(d.runId)<tostring(first.runId)) then first=d end
 end
 return first
end
function S:QueueResult(data) local db=Data(); db.pendingResults[data.runId]=L():Copy(data) end
local function Facts(d)
 return {gameId=d.gameId,runId=d.runId,slot=d.slot,ruleVersion=d.ruleVersion,catalogVersion=d.catalogVersion,scoreVersion=d.scoreVersion,
  difficulty=d.difficulty,score=d.score,result=d.result,board=d.board,stats=d.stats}
end
function S:ValidateResult(d,old)
 if type(d)~='table' or d.gameId~='HANGMAN' or d.ruleVersion~=1 or d.catalogVersion~=1 or d.scoreVersion~=1
  or not L():Int(d.slot,3) then return false end
 local b=L():ValidateBoard(d.board)
 if not b or A.HGM_Pets and not A.HGM_Pets:Get(b.petId) or d.difficulty~=b.difficulty
  or not L():Same(d.stats,{errors=b.errors}) then return false end
 if d.result=='WIN' then if not b.won or b.lost or d.score~=L().SCORES[b.difficulty] then return false end
 elseif d.result=='LOSS' then if not b.lost or b.won or d.score~=0 then return false end
 else return false end
 local frozen=old and old.hgmFacts or self:GetPending(d.slot)
 return frozen and L():Same(Facts(frozen),Facts(d)) or false
end
function S:ApplyResult(d)
 local db,st=Data(); local key=d.result=='WIN' and 'wins' or 'losses'
 st[key]=st[key]+1; db[key]=(tonumber(db[key]) or 0)+1
 if d.result=='WIN' and d.board.errors==0 then
  st.perfectWins=st.perfectWins+1
  local entry=A.ScoreManager:_EnsureEntry('HANGMAN',d.difficulty); entry.perfectWins=(entry.perfectWins or 0)+1
 end
 -- Existing slot snapshots are historical data; direct rounds never overwrite them.
 db.pendingResults[d.runId]=nil
end
