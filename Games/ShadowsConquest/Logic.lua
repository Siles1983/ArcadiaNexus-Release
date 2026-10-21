-- Versioned Lights Out rules; certified minima are prepared offline.
local L={DiffConfig={easy={gridSize=3,baseScore=100},normal={gridSize=5,baseScore=125},hard={gridSize=7,baseScore=200}}}
ArcadiaNexus.SC_Logic=L
function L:Int(n,m) return type(n)=='number' and n==n and n>=0 and n<=9007199254740991 and n%1==0 and (not m or n<=m) end
function L:Copy(t) if type(t)~='table' then return t end local r={} for k,v in pairs(t) do r[k]=self:Copy(v) end return r end
L.CloneGrid=L.Copy
function L:Same(a,b) if type(a)~=type(b) then return false end if type(a)~='table' then return a==b end for k,v in pairs(a) do if not self:Same(v,b[k]) then return false end end for k in pairs(b) do if a[k]==nil then return false end end return true end
function L:Dense(t,n) if type(t)~='table' then return false end local count=0 for k in pairs(t) do if not self:Int(k,n) or k<1 then return false end count=count+1 end return count==n end
function L:Grid(t,n) if not self:Dense(t,n) then return false end for _,row in ipairs(t) do if not self:Dense(row,n) then return false end for _,v in ipairs(row) do if v~=0 and v~=1 then return false end end end return true end
function L:ParsePuzzle(e)
 if type(e)~='table' or type(e.map)~='string' then return nil end local g={}
 for line in (e.map..'|'):gmatch('([^|]*)|') do if line=='' or line:find('[^01]') then return nil end local row={} for c=1,#line do row[c]=tonumber(line:sub(c,c)) end g[#g+1]=row end
 return self:Grid(g,#g) and g or nil
end
function L:Targets(s,r,c)
 if type(s)~='table' or not self:Int(s.gridSize,7) or s.gridSize<1 or not self:Int(r,s.gridSize) or r<1 or not self:Int(c,s.gridSize) or c<1 then return nil end
 local t={} for _,p in ipairs({{r,c},{r-1,c},{r+1,c},{r,c-1},{r,c+1}}) do if p[1]>=1 and p[1]<=s.gridSize and p[2]>=1 and p[2]<=s.gridSize then t[#t+1]=p end end return t
end
function L:Toggle(s,r,c)
 local t=self:Targets(s,r,c); if not t or not self:Grid(s.grid,s.gridSize) or not self:Int(s.moveCount,9007199254740990) or s.parity and not self:Grid(s.parity,s.gridSize) or s.movesLeft~=nil and (not self:Int(s.movesLeft) or s.movesLeft<1) then return false end
 for _,p in ipairs(t) do s.grid[p[1]][p[2]]=1-s.grid[p[1]][p[2]] end
 if s.parity then s.parity[r][c]=1-s.parity[r][c] end s.moveCount=s.moveCount+1
 if s.movesLeft then s.movesLeft=s.movesLeft-1 end return true
end
function L:IsWon(s) if type(s)~='table' or not self:Grid(s.grid,s.gridSize) then return false end for _,row in ipairs(s.grid) do for _,v in ipairs(row) do if v~=0 then return false end end end return true end
function L:IsMoveLimitReached(s) return s.moveLimitActive==true and s.movesLeft==0 end
function L:Entry(diff,index)
 local cfg=self.DiffConfig[diff]; if not cfg or not self:Int(index,50) or index<1 then return nil end
 local e=ArcadiaNexus.SC_Catalog[diff][index]; if type(e)~='table' or e.version~=2 or type(e.id)~='string' then return nil end
 local g=self:ParsePuzzle(e); local n=cfg.gridSize
 if not g or #g~=n or not self:Int(e.optimalMoves,n*n) or e.optimalMoves<1 or e.twoStars~=e.optimalMoves+math.max(2,math.ceil(e.optimalMoves/4)) or e.moveLimit~=e.optimalMoves+math.max(4,math.ceil(e.optimalMoves/2)) or not self:Dense(e.solution,e.optimalMoves) then return nil end
 local s={gridSize=n,grid=self:Copy(g),moveCount=0}; if self:IsWon(s) then return nil end
 for _,p in ipairs(e.solution) do if not self:Dense(p,2) or not self:Toggle(s,p[1],p[2]) then return nil end end
 return self:IsWon(s) and e or nil
end
function L:NewState(diff,e,unused,limit)
 if not self.DiffConfig[diff] or type(limit)~='boolean' then return nil end local grid=self:ParsePuzzle(e); if not grid or #grid~=self.DiffConfig[diff].gridSize then return nil end
 local p=self:Copy(grid); for _,row in ipairs(p) do for c in ipairs(row) do row[c]=0 end end
 return {ruleVersion=2,catalogVersion=2,ratingVersion=2,scoreVersion=2,difficulty=diff,gridSize=#grid,grid=grid,startGrid=self:Copy(grid),parity=p,moveCount=0,moveLimitActive=limit,movesLeft=limit and e.moveLimit or nil,puzzleId=e.id,puzzleOptimal=e.optimalMoves,cursorR=1,cursorC=1}
end
function L:ValidateState(s)
 if type(s)~='table' or s.ruleVersion~=2 or s.catalogVersion~=2 or s.ratingVersion~=2 or s.scoreVersion~=2 then return nil end
 local e=self:Entry(s.difficulty,s.puzzleIndex); if not e then return nil end local n=self.DiffConfig[s.difficulty].gridSize
 if s.gridSize~=n or s.puzzleId~=e.id or s.puzzleOptimal~=e.optimalMoves or type(s.moveLimitActive)~='boolean' or not self:Int(s.moveCount) or not self:Grid(s.grid,n) or not self:Grid(s.parity,n) or not self:Same(s.startGrid,self:ParsePuzzle(e)) or not self:Int(s.cursorR,n) or s.cursorR<1 or not self:Int(s.cursorC,n) or s.cursorC<1 then return nil end
 if s.moveLimitActive then if s.moveCount>e.moveLimit or s.movesLeft~=e.moveLimit-s.moveCount then return nil end elseif s.movesLeft~=nil then return nil end
 local replay={gridSize=n,grid=self:Copy(s.startGrid),moveCount=0}; local bits=0
 for r=1,n do for c=1,n do if s.parity[r][c]==1 then self:Toggle(replay,r,c); bits=bits+1 end end end
 if bits>s.moveCount or (s.moveCount-bits)%2~=0 or not self:Same(replay.grid,s.grid) then return nil end return self:Copy(s)
end
function L:Stars(s) local e=self:Entry(s.difficulty,s.puzzleIndex); if not e or not self:IsWon(s) then return 0 end return s.moveCount==e.optimalMoves and 3 or s.moveCount<=e.twoStars and 2 or 1 end
function L:CalcScore(s) if not self:IsWon(s) or s.moveCount<1 then return 0 end return math.floor(self.DiffConfig[s.difficulty].baseScore*s.puzzleOptimal/s.moveCount) end
function L:ScoreKey(diff,limit) return 'v2_'..(limit and 'limit_' or 'free_')..diff end
