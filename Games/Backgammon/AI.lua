local A, L = ArcadiaNexus, ArcadiaNexus.BG_Logic
A.BG_AI = {}
local function Value(board,seat,difficulty)
    local sg=seat==1 and 1 or -1
    local value=board.off[seat]*100+board.bar[3-seat]*22-L.Pips(board,seat)
    if difficulty=="hard" then value=value-board.bar[seat]*18+L.Pips(board,3-seat)*.08 end
    local run=0
    for p=1,24 do
        local count=board.points[p]*sg
        if count>=2 then
            local home=L.Distance(p,seat)<=6
            value=value+(home and 7 or 3)
            if difficulty=="hard" then
                value=value+(home and 5 or 1); run=run+1
                if run>=2 then value=value+5 end
            end
        elseif count==1 then
            run=0
            local exposed=board.bar[3-seat]>0
            for q=1,24 do if board.points[q]*sg<0 and (p-q)*sg>0 then exposed=true; break end end
            if exposed then value=value-(difficulty=="hard" and 15 or 9) end
        else run=0 end
    end
    return value
end
-- Same position scores; each DAG end position is evaluated only once.
A.BG_AI.Value=Value
function A.BG_AI.Choose(s,difficulty,turns,rng,checkpoint)
    if type(difficulty)=="table" then turns,difficulty=difficulty,"normal" end
    difficulty=difficulty=="easy" and "easy" or difficulty=="hard" and "hard" or "normal"
    turns=turns or L.BuildPolicy(s,checkpoint)
    if turns._policy then
        if not turns.root then return nil end
        local node,seq=turns.root,{}
        local bestEdges,values={},{}
        local function evaluate(n)
            if values[n] then return values[n] end
            if checkpoint then checkpoint() end
            local value=-math.huge
            if n.best==0 then value=Value(n.board,s.turn,difficulty)
            else for _,edge in ipairs(n.edges) do
                local candidate=evaluate(edge.child)
                if candidate>value then value=candidate; bestEdges[n]=edge end
            end end
            values[n]=value; return value
        end
        if difficulty~="easy" then evaluate(node) end
        while node.best>0 do
            local edge=bestEdges[node]
            if difficulty=="easy" then
                local index=(rng or math.random)(node.count)
                for _,candidate in ipairs(node.edges) do
                    index=index-candidate.child.count
                    if index<=0 then edge=candidate; break end
                end
            end
            seq[#seq+1]=edge.move; node=edge.child
        end
        return seq
    end
    -- Explicit leaf-array callers remain supported by the original API.
    if #turns==0 then return nil end
    if difficulty=="easy" then return turns[(rng or math.random)(#turns)] end
    local best,bestValue=nil,-math.huge
    for _,seq in ipairs(turns) do
        local board=s
        for _,move in ipairs(seq) do board=L.Step(board,s.turn,move) end
        local value=Value(board,s.turn,difficulty)
        if value>bestValue then best,bestValue=seq,value end
    end
    return best
end
