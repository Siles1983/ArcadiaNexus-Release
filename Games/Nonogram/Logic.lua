-- Pure Nonogram rules; catalog v2 is proved offline, never searched in the client.
local A=ArcadiaNexus
local L={CELL_EMPTY=0,CELL_FILLED=1,CELL_MARKED=2}
A.NON_Logic=L
L.DiffConfig={easy={gridSize=5,errorLimit=3,baseScoreFree=100,baseScoreStrict=150,errorBonus=25},normal={gridSize=10,errorLimit=4,baseScoreFree=250,baseScoreStrict=375,errorBonus=50},hard={gridSize=15,errorLimit=5,baseScoreFree=500,baseScoreStrict=750,errorBonus=100}}
L.CellSize={easy=36,normal=22,hard=16}
function L:Int(v,max) return type(v)=='number' and v==v and v>=0 and v<math.huge and v%1==0 and (not max or v<=max) end
function L:Copy(t) if type(t)~='table' then return t end local out={}; for k,v in pairs(t) do out[k]=self:Copy(v) end return out end
function L:Same(a,b) if type(a)~=type(b) then return false end if type(a)~='table' then return a==b end for k,v in pairs(a) do if not self:Same(v,b[k]) then return false end end for k in pairs(b) do if a[k]==nil then return false end end return true end
function L:Dense(t,n,max)
 if type(t)~='table' or #t~=n then return false end local count=0
 for k,v in pairs(t) do if not self:Int(k,n) or k<1 or max and not self:Int(v,max) then return false end count=count+1 end return count==n
end
function L:ValidGrid(grid,n) if not self:Dense(grid,n) then return false end for _,row in ipairs(grid) do if not self:Dense(row,n,2) then return false end end return true end
local function Groups(row)
 local out,run={},0
 for _,cell in ipairs(row) do if cell==1 then run=run+1 elseif run>0 then out[#out+1]=run; run=0 end end
 if run>0 then out[#out+1]=run end if #out==0 then out[1]=0 end return out
end
function L:CalcClues(grid,n)
 local rows,cols={},{}
 for r=1,n do rows[r]=Groups(grid[r]); local line={}; for c=1,n do line[c]=grid[c][r] end cols[r]=Groups(line) end return rows,cols
end
function L:ParsePuzzle(entry,n)
 if type(entry)~='table' or type(entry.map)~='string' then return nil end
 local grid={}; for line in (entry.map..'|'):gmatch('([^|]*)%|') do
  if #line~=n or line:find('[^01]') or #grid>=n then return nil end
  local row={}; for c=1,n do row[c]=tonumber(line:sub(c,c)) end grid[#grid+1]=row
 end
 if #grid~=n then return nil end local rows,cols=self:CalcClues(grid,n); return grid,rows,cols
end
function L:Entry(diff,index)
 if not self.DiffConfig[diff] or not self:Int(index,50) or index<1 then return nil end
 local e=A.LevelPool.GetEntry(A.NON_Catalog,diff,index)
 if not e or e.version~=2 or e.id~='non:2:'..diff..':'..index then return nil end return e
end
function L:CreateState(diff,mode,index,entry)
 local cfg=self.DiffConfig[diff]; if not cfg or mode~='free' and mode~='strict' then return nil end
 local sol,rows,cols=self:ParsePuzzle(entry,cfg.gridSize); if not sol then return nil end
 local grid={}; for r=1,cfg.gridSize do grid[r]={}; for c=1,cfg.gridSize do grid[r][c]=0 end end
 return {difficulty=diff,mode=mode,gridSize=cfg.gridSize,grid=grid,solution=sol,rowClues=rows,colClues=cols,puzzleIndex=index,puzzleName=entry.name,puzzleId=entry.id,puzzleMap=entry.map,errors=0,errorLimit=cfg.errorLimit,elapsedMs=0,timerActive=true,inputMode='fill',cursorR=1,cursorC=1,finalScore=0,won=false}
end
function L:CellInput(s,r,c,action)
 return s and not s.won and self:Int(r,s.gridSize) and r>=1 and self:Int(c,s.gridSize) and c>=1 and (action=='FILL' or action=='MARK')
end
function L:HandleClick(s,r,c,action)
 if not self:CellInput(s,r,c,action) then return 'invalid' end local cell=s.grid[r][c]
 if action=='MARK' then s.grid[r][c]=cell==2 and 0 or 2; return 'ok' end
 if cell==1 then s.grid[r][c]=0; return 'ok' end
 if s.mode=='strict' and s.solution[r][c]==0 then s.errors=s.errors+1; return s.errors>=s.errorLimit and 'gameover' or 'error' end
 s.grid[r][c]=1; return 'ok'
end
function L:CalcSolved(s)
 local rows,cols=self:CalcClues(s.grid,s.gridSize); local rs,cs={},{}
 for i=1,s.gridSize do rs[i]=self:Same(rows[i],s.rowClues[i]); cs[i]=self:Same(cols[i],s.colClues[i]) end return rs,cs
end
function L:CheckWin(s) local rs,cs=self:CalcSolved(s); for i=1,s.gridSize do if not rs[i] or not cs[i] then return false end end return true end
function L:MoveCursor(s,dr,dc)
 if type(dr)~='number' or type(dc)~='number' or dr%1~=0 or dc%1~=0 or math.abs(dr)+math.abs(dc)~=1 then return false end
 s.cursorR=math.max(1,math.min(s.gridSize,s.cursorR+dr)); s.cursorC=math.max(1,math.min(s.gridSize,s.cursorC+dc)); return true
end
function L:ToggleInputMode(s) s.inputMode=s.inputMode=='fill' and 'mark' or 'fill' end
function L:CalcScore(s) local cfg=self.DiffConfig[s.difficulty]; return s.mode=='free' and cfg.baseScoreFree or cfg.baseScoreStrict+math.max(0,cfg.errorLimit-s.errors)*cfg.errorBonus end
function L:CloneGrid(grid) return self:Copy(grid) end
function L:ScoreKey(diff,mode) return 'v2_'..mode..'_'..diff end
function L:ValidateState(s)
 if type(s)~='table' then return nil end local e=self:Entry(s.difficulty,s.puzzleIndex)
 if not e or s.puzzleId~=e.id or s.puzzleMap~=e.map then return nil end
 local clean=self:CreateState(s.difficulty,s.mode,s.puzzleIndex,e); if not clean then return nil end
 if not self:ValidGrid(s.grid,clean.gridSize) or not self:Int(s.elapsedMs) or not self:Int(s.errors,clean.errorLimit) or s.mode=='free' and s.errors~=0
  or not self:Int(s.cursorR,clean.gridSize) or s.cursorR<1 or not self:Int(s.cursorC,clean.gridSize) or s.cursorC<1 or s.inputMode~='fill' and s.inputMode~='mark' then return nil end
 clean.grid=self:Copy(s.grid); clean.elapsedMs=s.elapsedMs; clean.errors=s.errors; clean.cursorR=s.cursorR; clean.cursorC=s.cursorC; clean.inputMode=s.inputMode
 if s.mode=='strict' then for r=1,clean.gridSize do for c=1,clean.gridSize do if clean.grid[r][c]==1 and clean.solution[r][c]==0 then return nil end end end end
 return clean
end
