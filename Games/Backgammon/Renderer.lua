-- Persistent board skeleton: 24 point buttons, 30 checker textures, fixed labels/dice.
-- No frame allocation during moves, theme refreshes, saves or restarts.
local A, UI = ArcadiaNexus, ArcadiaNexus.UI
A.BG_Renderer = {}
local R = A.BG_Renderer
local ASSET = "Interface\\AddOns\\ArcadiaNexus\\Games\\Backgammon\\assets\\"
local LOGO_ASSET = ASSET .. "logo\\logo_backgammon"
local BORDER_ASSET = ASSET .. "border\\border_backgammon"
local BG_ASSET = ASSET .. "background\\background_backgammon"
local BOARD_ASSET = ASSET .. "board\\"
local CHECKER_ASSET = ASSET .. "checker\\"
local DIE_ASSET = ASSET .. "die\\"
local CFG = {
    -- The 512px source opening scales to exactly cover the 600x498 game canvas.
    border_w=800, border_h=550, border_ofs_x=0, border_ofs_y=15, border_alpha=1,
    bg_w=600, bg_h=498, bg_ofs_x=0, bg_ofs_y=0, bg_alpha=1,
    logo_w=380, logo_h=380, logo_ofs_x=0, logo_ofs_y=10, logo_alpha=1,
    board_w=560, board_h=328, board_ofs_x=0, board_ofs_y=-61,
    hud_ivory={w=177,h=30,x=20,y=-28,point="TOPLEFT",relativePoint="TOPLEFT"},
    hud_obsidian={w=177,h=30,x=-20,y=-28,point="TOPRIGHT",relativePoint="TOPRIGHT"},
    hud_turn={w=186,h=30,x=0,y=-28,point="TOP",relativePoint="TOP"},
    status={x=-20,y=-428,w=556},
    undo={w=85,h=28,x=-220,y=-400},
    action={w=165,h=28,x=194,y=-400},
    dice={
        {w=30,h=30,x=247,y=395}, {w=30,h=30,x=283,y=395},
        {w=30,h=30,x=319,y=395}, {w=30,h=30,x=335,y=395},
    },
    controls={
        -- Fine offsets relative to UI.CreateGameControlsBar's standard segments.
        start={w=144,h=32,ofs_x=0,ofs_y=0},
        difficulty={w=120,h=32,ofs_x=0,ofs_y=0},
        sync={w=130,h=32,ofs_x=0,ofs_y=0},
    },
}
local function Loc() return A.GetLocaleTable("BACKGAMMON") end
local function Engine() return A.BG_Engine end
local function Text(parent, size, x, y, width)
    local f = parent:CreateFontString(nil, "OVERLAY", size or "GameFontNormal")
    f:SetPoint("TOP", parent, "TOP", x or 0, y or 0)
    if width then f:SetWidth(width) end
    return f
end
local function Button(parent, label, w, h, x, y, callback)
    local b = UI.CreateArcadiaButton(parent, label, w, h)
    b:SetPoint("TOP", parent, "TOP", x, y)
    b:SetScript("OnClick", callback)
    return b
end
local function Enabled(button, yes)
    if yes then button:Enable(); button:SetAlpha(1) else button:Disable(); button:SetAlpha(0.4) end
end
local function Box(parent, w, h, x, y)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h); b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    b:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
    b:SetBackdropBorderColor(0, 0, 0, 0)
    return b
end
function R:Init()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end
    local viewport = UI.CreateGameViewport(gamesPanel, {outerName = "ArcadiaNexus_BG_Container"})
    self.frame, self.canvas = viewport.outer, viewport.canvas
    A._bgContainer = self.frame
    self.frame:Hide()
    self.frame:SetScript("OnShow", function() self:Render() end)
    self.frame:SetScript("OnHide", function()
        if A.HasMultiplayer() and A.Match.IsPresentingBoard() then return end
        A.GameSession:HandleRendererHide("BACKGAMMON", Engine(), function(e)
            if e.mode ~= "solo" then e:HideView() else e:SaveAndPause() end
        end)
    end)
    self:_CreateBoard()
    self:_CreateControls()
    self:Render()
end
function R:_CreateBoard()
    local c, loc = self.canvas, Loc()
    self._background = c:CreateTexture(nil, "BACKGROUND")
    self._background:SetSize(CFG.bg_w,CFG.bg_h); self._background:SetPoint("CENTER",c,"CENTER",CFG.bg_ofs_x,CFG.bg_ofs_y)
    self._background:SetAlpha(CFG.bg_alpha); self._background:SetTexture(BG_ASSET)
    self._logo = UI.CreateGameLogo(c, LOGO_ASSET, {w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y, alpha = CFG.logo_alpha})
    local hi, ho, ht = CFG.hud_ivory, CFG.hud_obsidian, CFG.hud_turn
    self.hud1, self.hudText1 = UI.CreateHudStatBox(c, {w=hi.w,h=hi.h,x=hi.x,y=hi.y,
        point=hi.point,relativePoint=hi.relativePoint,shown=false})
    self.hud2, self.hudText2 = UI.CreateHudStatBox(c, {w=ho.w,h=ho.h,x=ho.x,y=ho.y,
        point=ho.point,relativePoint=ho.relativePoint,shown=false})
    self.hudTurn, self.hudTurnText = UI.CreateHudStatBox(c, {w=ht.w,h=ht.h,x=ht.x,y=ht.y,
        point=ht.point,relativePoint=ht.relativePoint,shown=false})
    local board = CreateFrame("Frame", nil, c)
    board:SetSize(CFG.board_w,CFG.board_h); board:SetPoint("TOP", c, "TOP", CFG.board_ofs_x, CFG.board_ofs_y)
    self.board = board
    -- Child frames render above a texture placed directly on the canvas. Keep
    -- the decorative TGA frame in its own elevated overlay frame instead.
    self._borderFrame = CreateFrame("Frame", nil, c)
    self._borderFrame:SetSize(CFG.border_w,CFG.border_h)
    self._borderFrame:SetPoint("CENTER",c,"CENTER",CFG.border_ofs_x,CFG.border_ofs_y)
    self._borderFrame:SetFrameLevel(board:GetFrameLevel() + 10)
    self._border = self._borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    self._border:SetAllPoints(self._borderFrame)
    self._border:SetAlpha(CFG.border_alpha); self._border:SetTexture(BORDER_ASSET)
    self.boardTex = board:CreateTexture(nil, "BACKGROUND")
    self.boardTex:SetAllPoints(board)
    self.gold = UI.CreateGoldGridFrame(c, board, {pad = 1})
    self.points, self.checkers, self.counts = {}, {}, {}
    for slot = 1, 24 do
        local top = slot <= 12
        local col = (slot - 1) % 12
        local x, y = 18 + col * 38 + (col >= 6 and 24 or 0), top and 14 or 182
        local b = Box(board, 38, 132, x, y)
        b._slot = slot
        b:SetScript("OnClick", function() self:ClickPoint(b._point) end)
        local label = Text(b, "GameFontNormalSmall", 0, top and 12 or -133)
        label:SetTextColor(0.85, 0.72, 0.43)
        b._number = label
        local count = Text(b, "GameFontNormalSmall", 0, top and -113 or 0)
        count:SetTextColor(1, 0.85, 0.3)
        self.points[slot], self.counts[slot] = b, count
    end
    for i = 1, 30 do
        local tex = board:CreateTexture(nil, "ARTWORK")
        tex:SetSize(34, 34); tex:Hide(); self.checkers[i] = tex
    end
    self.barButton = Box(board, 24, 296, 246, 16)
    self.barButton:SetScript("OnClick", function() self:ClickPoint(0) end)
    self.barLabel = Text(self.barButton, "GameFontNormalSmall", 0, -136)
    self.barLabel:SetText(loc.bar)
    self.offButtons, self.offTexts = {}, {}
    for side = 1, 2 do
        local b = Box(board, 38, 132, 514, side == 1 and 182 or 14)
        b:SetScript("OnClick", function() self:ClickOff(b._seat) end)
        self.offTexts[side] = Text(b, "GameFontNormalSmall", 0, -53)
        self.offButtons[side] = b
    end
    self.status = Text(c, "GameFontNormalSmall", CFG.status.x, CFG.status.y, CFG.status.w)
    self.undo = Button(c, loc.btn_undo, CFG.undo.w, CFG.undo.h, CFG.undo.x, CFG.undo.y, function() Engine():Undo() end)
    self.action = Button(c, loc.btn_roll, CFG.action.w, CFG.action.h, CFG.action.x, CFG.action.y, function()
        local v = Engine():GetView()
        if v.pub.phase == "move" then Engine():Confirm() else Engine():Roll() end
    end)
    self.dice = {}
    for i = 1, 4 do
        local pos=CFG.dice[i]
        local b = Box(c, pos.w, pos.h, pos.x, pos.y)
        b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(b)
        b:SetScript("OnClick", function() self._die = b._die; self:Render() end)
        b:SetScript("OnEnter", function()
            if GameTooltip then GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText(Loc().dice_hint); GameTooltip:Show() end
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        self.dice[i] = b
    end
    self.slots = UI.CreateSaveSlotMenu({parent=c,maxSlots=3,L=loc,
        loadSlot=function(slot) return A.BG_Settings:LoadSlot(slot) end,
        deleteSlot=function(slot) A.BG_Settings:SaveSlot(slot,nil) end,
        formatInfo=function(save)
            local s = A.BG_Logic.Deserialize(save.board)
            return s and string.format(Loc().saved_info,s.turnNo,Loc()["difficulty_"..(save.difficulty or "normal")]) or Loc().bad_save
        end,
        onNewGame=function(slot) Engine():StartGame({slot=slot}) end,
        onContinue=function(slot) Engine():StartGame({slot=slot,resume=true}) end,
    })
end
function R:_CreateControls()
    local loc = Loc()
    local bar = UI.CreateGameControlsBar(self.frame,"narrow")
    local control=CFG.controls
    self.start = UI.CreateArcadiaButton(bar.frame,loc.btn_start,control.start.w,control.start.h)
    self.start:SetPoint("BOTTOM",bar.frame,"BOTTOM",bar.segX[2] + control.start.ofs_x,bar.y.button + control.start.ofs_y)
    self.start:SetScript("OnClick",function()
        local e = Engine()
        if e.state ~= "IDLE" and e.mode and e.mode ~= "solo" then
            local Shell = ArcadiaNexus.MatchShell
            if Shell and Shell.ShowEndRoundConfirm then
                Shell.ShowEndRoundConfirm(function()
                    UI.HideResultDialog(self.canvas)
                    e:SaveAndPause()
                    e:StopGame()
                end, self.canvas)
                return
            end
        end
        UI.HideResultDialog(self.canvas)
        if e.state ~= "IDLE" then e:SaveAndPause(); if e.mode ~= "solo" then e:StopGame() end
        elseif self.slots:IsShown() then self.slots:Hide(); self:Render()
        else self.slots:Show(); self:Render() end
    end)
    local ddAnchor=CreateFrame("Frame",nil,bar.frame)
    ddAnchor:SetSize(control.difficulty.w,control.difficulty.h)
    ddAnchor:SetPoint("CENTER",bar.frame,"CENTER",bar.segX[1] + control.difficulty.ofs_x,
        bar.y.dropdownOfs + control.difficulty.ofs_y)
    self.difficulty=UI.CreateSimpleDropdown(ddAnchor,0,0,control.difficulty.w,"",{
        {key="easy",label=loc.difficulty_easy},{key="normal",label=loc.difficulty_normal},{key="hard",label=loc.difficulty_hard},
    },function() return A.BG_Settings:Get("difficulty") end,function(key) A.BG_Settings:Set("difficulty",key) end)
    self.sync = UI.CreateArcadiaButton(bar.frame,loc.btn_sync,control.sync.w,control.sync.h)
    self.sync:SetPoint("BOTTOM",bar.frame,"BOTTOM",bar.segX[3] + control.sync.ofs_x,bar.y.button + control.sync.ofs_y)
    self.sync:SetScript("OnClick",function() Engine():Resync() end)
end
function R:ClickPoint(point)
    local v=Engine():GetView()
    if not v.canAct or v.pub.phase~="move" then return end
    if self._selected ~= nil then
        for _,m in ipairs(v.moves) do
            if m.from==self._selected and m.to==point and (not self._die or m.die==self._die) then
                self._selected=nil; Engine():Move(m.from,m.to,m.die); return
            end
        end
    end
    for _,m in ipairs(v.moves) do
        if m.from==point then
            self._selected=point
            -- Picking another checker must not leave a now-unusable die selected.
            local usable=false
            for _,x in ipairs(v.moves) do if x.from==point and x.die==self._die then usable=true end end
            if not usable then self._die=nil end
            self:Render(); return
        end
    end
    self._selected=nil; self:Render()
end
function R:ClickOff(seat)
    local v=Engine():GetView()
    if not v.canAct or seat~=v.pub.turn then return end
    for _,m in ipairs(v.moves) do
        if m.to==0 and m.from==self._selected and (not self._die or self._die==m.die) then
            self._selected=nil; Engine():Move(m.from,0,m.die); return
        end
    end
end
function R:Render()
    if not self.frame or not self.start then return end
    local e,loc=Engine(),Loc()
    local v=e:GetView()
    local active=v.state=="PLAYING" or v.state=="FINISHED"
    local slots=self.slots:IsShown() and not active
    if active then self.slots:Hide() end
    self.state=v.state
    self.board:SetShown(active); self.gold:SetShown(active)
    self.hud1:SetShown(active); self.hud2:SetShown(active); self.hudTurn:SetShown(active)
    self.status:SetShown(active); self.action:SetShown(active); self.undo:SetShown(active)
    self._logo:SetShown(not active and not slots)
    -- The decorative frame remains visible around both the idle view and the board.
    self._border:Show()
    self.difficulty:SetShown(not v.mp)
    self.sync:SetShown(v.mp and active and not v.isHost)
    self.difficulty:RefreshDisplay()
    self.difficulty:SetEnabled(not active and not v.mp)
    self.start:SetLabel(active and (v.mp and loc.btn_exit or loc.btn_save) or (slots and loc.btn_back or loc.btn_start))
    for _,b in ipairs(self.dice) do b:Hide() end
    if not active then
        UI.HideResultDialog(self.canvas)
        self._selected,self._die=nil,nil; return
    end
    local s,board=v.pub,v.board
    if self._revision~=s.revision then self._selected,self._die,self._revision=nil,nil,s.revision end
    local theme=A.BG_Settings:Get("theme")=="midnight" and "midnight" or "walnut"
    self.boardTex:SetTexture(BOARD_ASSET.."board_"..theme)
    self.hudText1:SetText(string.format(loc.pip,loc.player_1,A.BG_Logic.Pips(board,1)))
    self.hudText2:SetText(string.format(loc.pip,loc.player_2,A.BG_Logic.Pips(board,2)))
    self.hudTurnText:SetText(string.format(loc.turn,s.turnNo,loc["player_"..s.turn]))
    local flip=v.mp and v.seat==2
    local sources,targets={},{}
    for _,m in ipairs(v.moves) do
        sources[m.from]=true
        if m.from==self._selected and (not self._die or m.die==self._die) then targets[m.to]=true end
    end
    local used=0
    local function checker(seat,x,y)
        used=used+1
        local tex=self.checkers[used]
        tex:ClearAllPoints(); tex:SetPoint("TOPLEFT",self.board,"TOPLEFT",x,-y)
        tex:SetTexture(CHECKER_ASSET..(seat==1 and "checker_ivory" or "checker_obsidian")); tex:Show()
    end
    for slot,b in ipairs(self.points) do
        local top,col=slot<=12,(slot-1)%12
        local point=top and (13+col) or (12-col)
        if flip then point=25-point end
        b._point=point; b._number:SetText(point)
        local count=math.abs(board.points[point])
        local seat=board.points[point]>0 and 1 or 2
        local step=math.min(24,98/math.max(1,count-1))
        local x=20+col*38+(col>=6 and 24 or 0)
        for i=1,count do checker(seat,x,top and (16+(i-1)*step) or (278-(i-1)*step)) end
        self.counts[slot]:SetText(count>5 and tostring(count) or "")
        if v.canAct and targets[point] then b:SetBackdropBorderColor(0.35,1,0.64,0.95)
        elseif v.canAct and self._selected==point then b:SetBackdropBorderColor(1,0.82,0.25,1)
        elseif v.canAct and sources[point] then b:SetBackdropBorderColor(0.8,0.66,0.3,0.3)
        else b:SetBackdropBorderColor(0,0,0,0) end
    end
    for seat=1,2 do
        local bottom=(seat==1)~=flip
        local count=board.bar[seat]
        for i=1,count do checker(seat,241,bottom and (251-(i-1)*5) or (42+(i-1)*5)) end
    end
    for i=used+1,30 do self.checkers[i]:Hide() end
    self.barLabel:SetText(loc.bar.."\n"..board.bar[1]..":"..board.bar[2])
    self.barButton:SetBackdropBorderColor(1,0.82,0.25,v.canAct and sources[0] and 0.9 or 0)
    for side=1,2 do
        local seat=flip and 3-side or side
        self.offButtons[side]._seat=seat
        self.offTexts[side]:SetText(loc.off.."\n"..board.off[seat].."/15")
        self.offButtons[side]:SetBackdropBorderColor(0.35,1,0.64,v.canAct and targets[0] and seat==s.turn and 1 or 0)
    end
    local remaining={}
    for _,d in ipairs(v.remaining) do remaining[d]=(remaining[d] or 0)+1 end
    if self._die and not remaining[self._die] then self._die=nil end
    for i,die in ipairs(s.dice) do
        local b=self.dice[i]
        local available=(remaining[die] or 0)>0
        remaining[die]=math.max(0,(remaining[die] or 0)-1)
        b._die=die; b.tex:SetTexture(DIE_ASSET.."die_"..die); b:Show()
        Enabled(b,available and v.canAct and s.phase=="move")
        b:SetBackdropBorderColor(1,0.82,0.25,self._die==die and 1 or 0)
    end
    local status
    if s.phase=="over" then status=string.format(loc.victory,loc["player_"..s.winner])
    elseif v.pending then status=loc.sending
    elseif v.notice then status=loc[v.notice] or v.notice
    elseif not v.canAct then status=string.format(loc.waiting,loc["player_"..(s.phase=="opening" and 1 or s.turn)])
    elseif s.phase=="opening" then status=#s.dice==2 and loc.tie or loc.opening
    elseif s.phase=="roll" then status=string.format(loc.roll,loc["player_"..s.turn])
    elseif v.complete then status=v.draftCount==0 and loc.blocked or loc.confirm
    else status=loc.select end
    self.status:SetText(status)
    self.action:SetLabel(s.phase=="move" and (v.complete and v.draftCount==0 and loc.btn_pass or loc.btn_confirm) or loc.btn_roll)
    Enabled(self.action,v.canAct and (s.phase=="roll" or s.phase=="opening" or v.complete))
    Enabled(self.undo,v.canAct and v.draftCount>0)
    if s.winner~=0 and v.state=="FINISHED" and e._resultEmitted and not e._dialogShown and self.frame:IsShown() then
        e._dialogShown=true; self:ShowGameOver(v)
    end
end
function R:ShowGameOver(v)
    local loc,e=Loc(),Engine()
    local won=v.pub.winner==v.seat
    local lines={loc["win_"..v.pub.pointsWon]}
    UI.ShowArcadeResult(self.canvas,{gameId="BACKGAMMON",L=loc,
        title=string.format(loc.victory,loc["player_"..v.pub.winner]),
        result=won and "WIN" or "LOSS",lines=lines,hideHighscore=true,
        onRetry=function()
            if v.mp then
                local Shell = ArcadiaNexus.MatchShell
                if Shell and Shell.Rematch then Shell.Rematch("BACKGAMMON") end
            else
                e:StartGame({slot=e.slot})
            end
        end,
        onExit=function() e:StopGame() end,
    })
end
function R:EnterIdleState() self:Render() end
A.RegisterGame({id="BACKGAMMON",label="Backgammon",renderer="BG_Renderer",engine="BG_Engine",
    container="_bgContainer",category="STRATEGIE",matchSeats=2,logo=ASSET .. "logo",xp=10})
