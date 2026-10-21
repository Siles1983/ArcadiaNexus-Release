-- The decision API accepts public observations only, never a fleet board.
local A = _G.ArcadiaNexus
A.AC_AI = {}
local AI = A.AC_AI

function AI:NewKnowledge(size, lengths)
    local k = {size=size, shots={}, remaining=A.AC_Logic:Copy(lengths)}
    for r=1,size do k.shots[r]={}; for c=1,size do k.shots[r][c]="UNKNOWN" end end
    return k
end

function AI:Observe(k, shot, revealed)
    k.shots[shot.r][shot.c] = shot.result
    if shot.result == "SUNK" then
        for _,cell in ipairs(revealed.cells) do k.shots[cell.r][cell.c]="SUNK" end
        for i,len in ipairs(k.remaining) do
            if len==revealed.length then table.remove(k.remaining,i); break end
        end
    end
end

local function pick(list) return #list>0 and list[math.random(1,#list)] or nil end
function AI:GetBestMove(k, difficulty)
    local all, parity, neighbors, seen = {}, {}, {}, {}
    local dirs={{1,0},{-1,0},{0,1},{0,-1}}
    for r=1,k.size do for c=1,k.size do
        if k.shots[r][c]=="UNKNOWN" then
            local cell={r=r,c=c}; all[#all+1]=cell
            if (r+c)%2==0 then parity[#parity+1]=cell end
        elseif k.shots[r][c]=="HIT" then
            for _,d in ipairs(dirs) do
                local nr,nc=r+d[1],c+d[2]; local key=nr*k.size+nc
                if nr>=1 and nr<=k.size and nc>=1 and nc<=k.size and k.shots[nr][nc]=="UNKNOWN" and not seen[key] then
                    seen[key]=true; neighbors[#neighbors+1]={r=nr,c=nc}
                end
            end
        end
    end end
    if difficulty=="easy" then return pick(all) end
    if difficulty~="hard" then return pick(neighbors) or pick(parity) or pick(all) end

    local hunt,target={},{}
    for r=1,k.size do hunt[r]={}; target[r]={}
        for c=1,k.size do hunt[r][c]=0; target[r][c]=0 end
    end
    -- Each straight hypothesis is independent: touching hits may belong to
    -- different ships. No diagonal line, hidden IDs or global hit clustering.
    local targetExists=false
    for _,len in ipairs(k.remaining) do
        for r=1,k.size do for c=1,k.size do for axis=1,2 do
            local cells, hits, valid={},0,true
            for i=0,len-1 do
                local nr,nc=r+(axis==2 and i or 0),c+(axis==1 and i or 0)
                local state=k.shots[nr] and k.shots[nr][nc]
                if not state or state=="MISS" or state=="SUNK" then valid=false; break end
                if state=="HIT" then hits=hits+1 end
                cells[#cells+1]={r=nr,c=nc}
            end
            if valid then for _,cell in ipairs(cells) do
                if k.shots[cell.r][cell.c]=="UNKNOWN" then
                    hunt[cell.r][cell.c]=hunt[cell.r][cell.c]+1
                    if hits>0 then targetExists=true; target[cell.r][cell.c]=target[cell.r][cell.c]+hits*hits end
                end
            end end
        end end end
    end
    local scores=targetExists and target or hunt
    local best,list=-1,{}
    for _,cell in ipairs(all) do
        local score=scores[cell.r][cell.c]
        if score>best then best,list=score,{cell}
        elseif score==best then list[#list+1]=cell end
    end
    return pick(list)
end
