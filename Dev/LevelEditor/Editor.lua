--[[
    ArcadiaNexus – Dev/LevelEditor/Editor.lua
    Phase 15: Erde, Treppen, Emitter, Inspect-Gating.

    Slash: /anledit   /pledit
    Nur bei IsDevMode(). Kein RegisterGame, keine Session im Hub.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LevelEditor = {}
local LE = ArcadiaNexus.LevelEditor

local function L(key, fallback)
    local locales = ArcadiaNexus._locales and ArcadiaNexus._locales.LEVELEDITOR
    local lang = ArcadiaNexus.ActiveLocale or "enUS"
    local s = locales and (
        (locales[lang] and locales[lang][key])
        or (locales.enUS and locales.enUS[key])
    )
    if type(s) == "string" and s ~= "" then return s end
    return fallback or key
end

local TILE = 32
local PAL_W = 210
local TOOL_H = 64
local STATUS_H = 26
local INSPECT_H = 304

local WHITE = "Interface\\Buttons\\WHITE8X8"

LE._frame = nil
LE._mode = "edit"   -- edit | play
LE._draft = nil
LE._brush = "#"
LE._qContents = "random"
LE._moverAxis = "h"
LE._moverSpan = "4"
LE._spinMode = "90"
LE._pipePair = "1"
LE._patrol = "4"
LE._mobBehavior = "turn"
LE._camLock = "xy"
LE._bossType = "golem"
LE._emitDir = "u"
LE._undo = {}
LE._clip = nil
LE._sel = nil
LE._hoverCol, LE._hoverRow = 1, 1
LE._camX = 0
LE._camY = 0
LE._paintBtn = nil
LE._panning = false
LE._panStartX, LE._panStartY = 0, 0
LE._panCamX, LE._panCamY = 0, 0
LE._gs = nil
LE._dirty = true
LE._groupOpen = nil
LE._animT = 0
LE._lastAnimRedraw = 0

local _gameLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_LevelEditor_Loop")

local function Catalog()
    return ArcadiaNexus.LevelEditorCatalog
end

local function Ser()
    return ArcadiaNexus.LevelEditorSerialize
end

local function UI()
    return ArcadiaNexus.UI
end

local function DraftGame()
    return Catalog().NormalizeGame(LE._draft and LE._draft.game)
end

local function PlayLogic()
    if DraftGame() == Catalog().GAME_TR then
        return ArcadiaNexus.TR_Logic
    end
    return ArcadiaNexus.AA_Logic
end

local function BindLabelTip(fs, parent, title, text)
    if not fs or not parent then return end
    local hit = CreateFrame("Frame", nil, parent)
    hit:SetPoint("TOPLEFT", fs, "TOPLEFT", -2, 2)
    hit:SetSize(PAL_W - 40, 14)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", function(self)
        UI().ShowFrameTooltip(self, title, text)
    end)
    hit:SetScript("OnLeave", function()
        UI().HideFrameTooltip()
    end)
end

local function CanOpen()
    return ArcadiaNexus.IsDevMode and ArcadiaNexus.IsDevMode()
end

local function EnsureDB()
    if not ArcadiaNexusDB then return nil end
    ArcadiaNexusDB.dev = ArcadiaNexusDB.dev or {}
    local d = ArcadiaNexusDB.dev.levelEditor
    if type(d) ~= "table" then
        d = {}
        ArcadiaNexusDB.dev.levelEditor = d
    end
    return d
end

local function SaveDraft()
    local db = EnsureDB()
    if not db or not LE._draft then return end
    db.name = LE._draft.name
    db.width = LE._draft.width
    db.height = LE._draft.height
    db.theme = LE._draft.theme
    db.parallax = LE._draft.parallax
    db.game = DraftGame()
    db.map = Ser().ToMapString(LE._draft)
    db.camX = LE._camX
    db.camY = LE._camY
    db.brush = LE._brush
    db.qContents = LE._qContents
    db.pipePair = LE._pipePair
    db.groupOpen = LE._groupOpen
    local list = Ser().BlocksList(LE._draft)
    db.blocks = list
    db.pipes = Ser().PipesList(LE._draft)
    db.mobs = Ser().MobsList(LE._draft)
    db.props = Ser().PropsList(LE._draft)
    db.boss = LE._draft.boss
    db.patrol = LE._patrol
    db.mobBehavior = LE._mobBehavior
    db.camLock = LE._camLock
    db.bossType = LE._bossType
    db.emitDir = LE._emitDir
end

local function LoadDraft()
    local db = EnsureDB()
    if db and type(db.map) == "string" and db.width and db.height then
        return Ser().FromMapString({
            name = db.name or "Draft",
            width = db.width,
            height = db.height,
            theme = db.theme or "day",
            parallax = db.parallax,
            game = db.game,
            map = db.map,
            blocks = db.blocks,
            pipes = db.pipes,
            mobs = db.mobs,
            props = db.props,
            boss = db.boss,
        })
    end
    return Ser().Blank(80, 24)
end

local function ViewWH()
    local v = LE._view
    if v then
        local w, h = v:GetWidth(), v:GetHeight()
        if w and w > 1 and h and h > 1 then
            return w, h
        end
    end
    return 1100, 720
end

local function EnsureGroups()
    if type(LE._groupOpen) ~= "table" then
        LE._groupOpen = {
            terrain = true, hazard = true, block = true,
            marker = true, pickup = true, enemy = true, decor = true,
        }
    end
end

local function PushUndo()
    local S = Ser()
    if not LE._draft then return end
    LE._undo = LE._undo or {}
    LE._undo[#LE._undo + 1] = S.CloneDraft(LE._draft)
    while #LE._undo > 30 do
        table.remove(LE._undo, 1)
    end
end

local function Undo()
    if not LE._undo or #LE._undo == 0 then return end
    LE._draft = table.remove(LE._undo)
    LE._dirty = true
    LE:_Redraw()
    LE:_RefreshSizeLabel()
    SaveDraft()
end

local function ClampCam()
    local d = LE._draft
    if not d then return end
    local vw, vh = ViewWH()
    local maxX = math.max(0, d.width * TILE - vw)
    local maxY = math.max(0, d.height * TILE - vh)
    if LE._camX < 0 then LE._camX = 0 end
    if LE._camY < 0 then LE._camY = 0 end
    if LE._camX > maxX then LE._camX = maxX end
    if LE._camY > maxY then LE._camY = maxY end
end

local function CursorToView()
    local view = LE._view
    if not view then return nil, nil end
    local x, y = GetCursorPosition()
    local scale = view:GetEffectiveScale()
    x, y = x / scale, y / scale
    local left, top = view:GetLeft(), view:GetTop()
    if not left or not top then return nil, nil end
    return x - left, top - y
end

local function ViewToCell(lx, ly)
    local col = math.floor((lx + LE._camX) / TILE) + 1
    local row = math.floor((ly + LE._camY) / TILE) + 1
    return col, row
end

local LIQUID_FILL_A = 0.58

local function AcquireTex(pool, parent)
    local tex = table.remove(pool.free)
    if not tex then
        tex = parent:CreateTexture(nil, "ARTWORK")
    end
    tex:Show()
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetAlpha(1)
    tex:SetVertexColor(1, 1, 1, 1)
    if tex.SetDrawLayer then tex:SetDrawLayer("ARTWORK", 0) end
    if tex.SetRotation then tex:SetRotation(0) end
    pool.used[#pool.used + 1] = tex
    return tex
end

local function ReleaseAll(pool)
    for i = 1, #pool.used do
        local tex = pool.used[i]
        tex:Hide()
        tex:ClearAllPoints()
        if tex.SetRotation then tex:SetRotation(0) end
        pool.free[#pool.free + 1] = tex
    end
    wipe(pool.used)
end

function LE:_EnsurePools()
    if self._tilePool then return end
    self._tilePool = { used = {}, free = {} }
    self._actorPool = { used = {}, free = {} }
    self._propPool = { used = {}, free = {} }
    self._markPool = { used = {}, free = {} }
end

local function AcquireFS(pool, parent)
    local fs = table.remove(pool.free)
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    end
    fs:Show()
    pool.used[#pool.used + 1] = fs
    return fs
end

function LE:_PaintCell(col, row, ch)
    local Cat = Catalog()
    local item = Cat.ByChar(ch, DraftGame())
    if item and item.overlay then
        if Ser().SetProp(self._draft, col, row, item.propKind or item.id, {
            axis = self._moverAxis,
            span = self._moverSpan,
            spin = self._spinMode,
            cam = self._camLock,
            dir = Cat.NormalizeEmitDir(self._emitDir),
        }) then
            self._dirty = true
        end
        return
    end
    local opts = nil
    if ch == "?" then
        opts = { contents = self._qContents }
    elseif Cat.IsPairChar(ch, DraftGame()) then
        opts = { pair = self._pipePair }
    elseif Cat.IsMobChar(ch, DraftGame()) then
        opts = { patrol = self._patrol, behavior = self._mobBehavior }
    elseif ch == "B" then
        opts = { boss = self._bossType }
    end
    if Ser().Set(self._draft, col, row, ch, opts) then
        self._dirty = true
    end
end

function LE:_Redraw()
    local Cat = Catalog()
    local d = self._draft
    local holder = self._holder
    if not d or not holder then return end
    self:_EnsurePools()
    ReleaseAll(self._tilePool)
    ReleaseAll(self._actorPool)
    ReleaseAll(self._propPool)
    ReleaseAll(self._markPool)

    holder:SetSize(d.width * TILE, d.height * TILE)
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", self._view, "TOPLEFT", -self._camX, self._camY)

    local vw, vh = ViewWH()
    local c0 = math.max(1, math.floor(self._camX / TILE) + 1)
    local r0 = math.max(1, math.floor(self._camY / TILE) + 1)
    local c1 = math.min(d.width, c0 + math.ceil(vw / TILE) + 1)
    local r1 = math.min(d.height, r0 + math.ceil(vh / TILE) + 1)

    local source = d
    local gs = self._gs
    if self._mode == "play" and gs and gs.lv then
        source = nil
    end
    local phase01
    if self._mode == "play" and gs and gs.waterPhase then
        phase01 = gs.waterPhase
    else
        phase01 = ((self._animT or 0) * 0.8) % 1
    end

    for r = r0, r1 do
        for c = c0, c1 do
            local ch
            if source then
                ch = Ser().Get(d, c, r)
            else
                ch = gs.lv.grid[r] and gs.lv.grid[r][c] or "."
            end
            local game = DraftGame()
            local skipTree = (game ~= Catalog().GAME_TR)
                and (ch == "t" or ch == "T" or ch == "u")
            if ch ~= "." and ch ~= "" and not skipTree then
                local item = Cat.ByChar(ch, game)
                local tex = AcquireTex(self._tilePool, holder)
                tex:SetSize(TILE, TILE)
                tex:SetPoint("TOPLEFT", holder, "TOPLEFT", (c - 1) * TILE, -(r - 1) * TILE)
                tex:SetVertexColor(1, 1, 1, 1)
                if game ~= Cat.GAME_TR and Cat.IsWaterChar(ch) then
                    local above
                    if source then
                        above = (r > 1) and Ser().Get(d, c, r - 1) or "."
                    else
                        above = (r > 1) and gs.lv.grid[r - 1] and gs.lv.grid[r - 1][c] or "."
                    end
                    local deep = Cat.IsWaterChar(above)
                    if deep then
                        Cat.ApplyTexture(tex, Cat.WATER_FILL)
                        tex:SetAlpha(LIQUID_FILL_A)
                    else
                        Cat.ApplyTexture(tex, Cat.WaterTex(phase01))
                    end
                    if tex.SetDrawLayer then tex:SetDrawLayer("OVERLAY", 2) end
                    if ch == "w" or ch == "i" then tex:SetVertexColor(0.55, 0.9, 1, 0.9) end
                    if deep then tex:SetAlpha(LIQUID_FILL_A) end
                elseif game ~= Cat.GAME_TR and Cat.IsLavaChar(ch) then
                    local above
                    if source then
                        above = (r > 1) and Ser().Get(d, c, r - 1) or "."
                    else
                        above = (r > 1) and gs.lv.grid[r - 1] and gs.lv.grid[r - 1][c] or "."
                    end
                    local deep = Cat.IsLavaChar(above)
                    if deep then
                        Cat.ApplyTexture(tex, Cat.LAVA_FILL)
                        tex:SetAlpha(LIQUID_FILL_A)
                    else
                        Cat.ApplyTexture(tex, Cat.LavaTex(phase01))
                    end
                    if tex.SetDrawLayer then tex:SetDrawLayer("OVERLAY", 2) end
                elseif ch == "b" then
                    local hp = 3
                    if gs and gs.lv and gs.lv.breakables then
                        for i = 1, #gs.lv.breakables do
                            local br = gs.lv.breakables[i]
                            if br.col == c and br.row == r then
                                hp = br.hp or 3
                                break
                            end
                        end
                    end
                    Cat.ApplyTexture(tex, Cat.BreakTex(hp))
                elseif item then
                    local rec = Cat.ItemTex(item, game)
                    if ch == "#" and game ~= Cat.GAME_TR then
                        local above
                        if source then
                            above = (r > 1) and Ser().Get(d, c, r - 1) or "."
                        else
                            above = (r > 1) and gs.lv.grid[r - 1] and gs.lv.grid[r - 1][c] or "."
                        end
                        if Cat.CoversGround(above) then
                            rec = Cat.ItemTex(Cat.Get("dirt"), game)
                        end
                    end
                    if rec then
                        Cat.ApplyTexture(tex, rec)
                    else
                        tex:SetTexture(WHITE)
                        tex:SetVertexColor(0.4, 0.7, 1, 0.85)
                    end
                else
                    tex:SetTexture(WHITE)
                    tex:SetVertexColor(0.4, 0.7, 1, 0.85)
                end
                if self._mode == "edit" and ch == "?" then
                    local mark = AcquireFS(self._markPool, holder)
                    local contents = Ser().GetBlockContents(d, c, r)
                    mark:SetText(Cat.QBLOCK_MARK[contents] or "?")
                    mark:SetTextColor(1, 0.92, 0.35)
                    mark:ClearAllPoints()
                    mark:SetPoint("CENTER", holder, "TOPLEFT",
                        (c - 0.5) * TILE, -(r - 0.5) * TILE)
                elseif self._mode == "edit" and Catalog().IsPairChar(ch, game) then
                    local mark = AcquireFS(self._markPool, holder)
                    mark:SetText(tostring(Ser().GetPipePair(d, c, r)))
                    mark:SetTextColor(0.45, 1, 0.55)
                    mark:ClearAllPoints()
                    mark:SetPoint("CENTER", holder, "TOPLEFT",
                        (c - 0.5) * TILE, -(r - 0.5) * TILE)
                elseif self._mode == "edit" and ch == "z" then
                    tex:SetAlpha(0.35)
                elseif self._mode == "play" and ch == "D" and gs and gs.openPairs then
                    local pair = 1
                    if gs.lv and gs.lv.pairAt then
                        pair = gs.lv.pairAt[c .. ":" .. r] or 1
                    end
                    if gs.openPairs[pair] then tex:SetAlpha(0.25) end
                end
            end
        end
    end

    self:_DrawDecor(holder, d, gs)
    self:_DrawMovers(holder, d, gs)
    self:_DrawDynamics(holder, d, gs)
    if self._mode == "edit" and self._sel then
        local s = self._sel
        local c0, c1 = math.min(s.c0, s.c1), math.max(s.c0, s.c1)
        local r0, r1 = math.min(s.r0, s.r1), math.max(s.r0, s.r1)
        for r = r0, r1 do
            for c = c0, c1 do
                local tex = AcquireTex(self._tilePool, holder)
                tex:SetTexture(WHITE)
                tex:SetVertexColor(1, 0.85, 0.2, 0.22)
                tex:SetSize(TILE, TILE)
                tex:SetPoint("TOPLEFT", holder, "TOPLEFT", (c - 1) * TILE, -(r - 1) * TILE)
            end
        end
    end

    if self._mode == "play" and gs then
        self:_DrawPlayActors(gs, holder)
    end

    self._dirty = false
    self:_RefreshStatus()
end

local function PlaceFoot(tex, holder, x, y, w, h)
    tex:SetSize(w, h)
    tex:ClearAllPoints()
    tex:SetPoint("BOTTOM", holder, "TOPLEFT", x, -y)
end

local function PlaceCenter(tex, holder, x, y, w, h)
    tex:SetSize(w, h)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", holder, "TOPLEFT", x, -y)
end

local TREE_SIZE = {
    t = { w = 80, h = 160, variant = 1 },
    T = { w = 104, h = 208, variant = 2 },
    u = { w = 136, h = 272, variant = 3 },
}

function LE:_DrawDecor(holder, d, gs)
    local Cat = Catalog()
    if DraftGame() == Cat.GAME_TR then
        if self._mode == "play" and gs and gs.lv then
            for i = 1, #(gs.lv.decorProps or {}) do
                local prop = gs.lv.decorProps[i]
                local rec = Cat.ByPropKind(prop.kind)
                if rec and rec.propKind ~= "mover" and rec.propKind ~= "crate"
                    and rec.propKind ~= "fallplat" and rec.propKind ~= "spinner" then
                    local tex = AcquireTex(self._propPool, holder)
                    Cat.ApplyTexture(tex, rec.tex)
                    if rec.anchor == "center" then
                        PlaceCenter(tex, holder, prop.x, prop.y, rec.drawW or 32, rec.drawH or 32)
                    else
                        PlaceFoot(tex, holder, prop.x, prop.y, rec.drawW or 32, rec.drawH or 32)
                    end
                end
            end
        elseif d then
            local props = Ser().PropsList(d)
            for i = 1, #props do
                local p = props[i]
                local rec = Cat.ByPropKind(p.kind)
                if rec and rec.propKind ~= "mover" and rec.propKind ~= "crate"
                    and rec.propKind ~= "fallplat" and rec.propKind ~= "spinner" then
                    local tex = AcquireTex(self._propPool, holder)
                    Cat.ApplyTexture(tex, rec.tex)
                    local x = (p.col - 0.5) * TILE
                    if rec.anchor == "center" then
                        PlaceCenter(tex, holder, x, (p.row - 0.5) * TILE, rec.drawW or 32, rec.drawH or 32)
                    else
                        PlaceFoot(tex, holder, x, p.row * TILE, rec.drawW or 32, rec.drawH or 32)
                    end
                end
            end
        end
        return
    end
    if self._mode == "play" and gs and gs.lv then
        for i = 1, #(gs.lv.decorTrees or {}) do
            local tree = gs.lv.decorTrees[i]
            local rec = Cat.Get((tree.variant == 1 and "tree1") or (tree.variant == 3 and "tree3") or "tree2")
            local tex = AcquireTex(self._propPool, holder)
            if rec then Cat.ApplyTexture(tex, rec.tex) end
            PlaceFoot(tex, holder, tree.x, tree.y, tree.w or 104, tree.h or 208)
        end
        for i = 1, #(gs.lv.decorProps or {}) do
            local prop = gs.lv.decorProps[i]
            local rec = Cat.ByPropKind(prop.kind)
            if rec and rec.propKind ~= "mover" and rec.propKind ~= "crate"
                and rec.propKind ~= "fallplat" and rec.propKind ~= "spinner" then
                local tex = AcquireTex(self._propPool, holder)
                Cat.ApplyTexture(tex, rec.tex)
                if rec.anchor == "center" then
                    PlaceCenter(tex, holder, prop.x, prop.y, rec.drawW or 32, rec.drawH or 32)
                else
                    PlaceFoot(tex, holder, prop.x, prop.y, rec.drawW or 32, rec.drawH or 32)
                end
            end
        end
        return
    end
    if not d then return end
    for r = 1, d.height do
        for c = 1, d.width do
            local ch = Ser().Get(d, c, r)
            local sz = TREE_SIZE[ch]
            if sz then
                local rec = Cat.Get((sz.variant == 1 and "tree1") or (sz.variant == 3 and "tree3") or "tree2")
                local tex = AcquireTex(self._propPool, holder)
                if rec then Cat.ApplyTexture(tex, rec.tex) end
                PlaceFoot(tex, holder, (c - 0.5) * TILE, r * TILE, sz.w, sz.h)
            end
        end
    end
    local props = Ser().PropsList(d)
    for i = 1, #props do
        local p = props[i]
        local rec = Cat.ByPropKind(p.kind)
        if rec and rec.propKind ~= "mover" and rec.propKind ~= "crate"
            and rec.propKind ~= "fallplat" and rec.propKind ~= "spinner" then
            local tex = AcquireTex(self._propPool, holder)
            Cat.ApplyTexture(tex, rec.tex)
            local x = (p.col - 0.5) * TILE
            if rec.anchor == "center" then
                PlaceCenter(tex, holder, x, (p.row - 0.5) * TILE, rec.drawW or 32, rec.drawH or 32)
            else
                PlaceFoot(tex, holder, x, p.row * TILE, rec.drawW or 32, rec.drawH or 32)
            end
        end
    end
end

local MOVER_DRAW_W = 64
local MOVER_DRAW_H = 12

function LE:_DrawOneMover(holder, rec, cx, footY, ghost)
    local tex = AcquireTex(self._propPool, holder)
    if rec then Catalog().ApplyTexture(tex, rec.tex) end
    PlaceFoot(tex, holder, cx, footY, MOVER_DRAW_W, MOVER_DRAW_H)
    if ghost then
        tex:SetVertexColor(1, 1, 1, 0.35)
    else
        tex:SetVertexColor(1, 1, 1, 1)
    end
end

function LE:_DrawMovers(holder, d, gs)
    if DraftGame() ~= Catalog().GAME_AA then return end
    local rec = Catalog().ByPropKind("mover")
    if self._mode == "play" and gs and gs.movers then
        for i = 1, #gs.movers do
            local m = gs.movers[i]
            self:_DrawOneMover(holder, rec, m.x + MOVER_DRAW_W * 0.5, m.top + MOVER_DRAW_H, false)
        end
        return
    end
    if not d then return end
    local props = Ser().PropsList(d)
    for i = 1, #props do
        local p = props[i]
        if p.kind == "mover" then
            local left = (p.col - 1) * TILE
            local top = (p.row - 1) * TILE
            self:_DrawOneMover(holder, rec, left + MOVER_DRAW_W * 0.5, top + MOVER_DRAW_H, false)
            local span = tonumber(p.span) or 4
            local gx, gy = left, top
            if p.axis == "v" then
                gy = top - span * TILE
            else
                gx = left + span * TILE
            end
            self:_DrawOneMover(holder, rec, gx + MOVER_DRAW_W * 0.5, gy + MOVER_DRAW_H, true)
        end
    end
end

function LE:_DrawDynamics(holder, d, gs)
    if DraftGame() ~= Catalog().GAME_AA then return end
    local Cat = Catalog()
    local crateRec, fallRec, spinRec = Cat.ByPropKind("crate"), Cat.ByPropKind("fallplat"), Cat.ByPropKind("spinner")
    if self._mode == "play" and gs then
        for i = 1, #(gs.crates or {}) do
            local c = gs.crates[i]
            local tex = AcquireTex(self._propPool, holder)
            if crateRec then Cat.ApplyTexture(tex, crateRec.tex) end
            PlaceFoot(tex, holder, c.x + c.w * 0.5, c.y, c.w, c.h)
        end
        for i = 1, #(gs.falls or {}) do
            local f = gs.falls[i]
            if f.alive ~= false then
                local tex = AcquireTex(self._propPool, holder)
                if fallRec then Cat.ApplyTexture(tex, fallRec.tex) end
                local ox = 0
                if (f.shake or 0) > 0 then
                    ox = math.sin((f.wobble or 0)) * 3
                end
                PlaceFoot(tex, holder, f.x + f.w * 0.5 + ox, f.top + f.h, f.w, f.h)
            end
        end
        for i = 1, #(gs.spinners or {}) do
            local s = gs.spinners[i]
            local tex = AcquireTex(self._propPool, holder)
            if spinRec then Cat.ApplyTexture(tex, spinRec.tex) end
            PlaceCenter(tex, holder, s.cx, s.cy, 64, 12)
            if tex.SetRotation then tex:SetRotation(s.angle or 0) end
        end
        return
    end
    if not d then return end
    local props = Ser().PropsList(d)
    for i = 1, #props do
        local p = props[i]
        if p.kind == "crate" then
            local tex = AcquireTex(self._propPool, holder)
            if crateRec then Cat.ApplyTexture(tex, crateRec.tex) end
            PlaceFoot(tex, holder, (p.col - 0.5) * TILE, p.row * TILE, 28, 28)
        elseif p.kind == "fallplat" then
            local tex = AcquireTex(self._propPool, holder)
            if fallRec then Cat.ApplyTexture(tex, fallRec.tex) end
            PlaceFoot(tex, holder, (p.col - 1) * TILE + 32, p.row * TILE, 64, 12)
        elseif p.kind == "spinner" then
            local tex = AcquireTex(self._propPool, holder)
            if spinRec then Cat.ApplyTexture(tex, spinRec.tex) end
            PlaceCenter(tex, holder, (p.col - 0.5) * TILE, (p.row - 0.5) * TILE, 64, 12)
        end
    end
end

function LE:_DrawPlayActors(gs, holder)
    local Cat = Catalog()
    local game = DraftGame()
    local p = gs.player
    local ptex = AcquireTex(self._actorPool, holder)
    local spawnRec = Cat.Get("spawn")
    Cat.ApplyTexture(ptex, Cat.ItemTex(spawnRec, game))
    PlaceFoot(ptex, holder, p.x, p.y, 28, 32)
    if p.dir and p.dir < 0 then
        ptex:SetTexCoord(1, 0, 0, 1)
    else
        ptex:SetTexCoord(0, 1, 0, 1)
    end

    for i = 1, #(gs.lv and gs.lv.checkpoints or {}) do
        local cp = gs.lv.checkpoints[i]
        local tex = AcquireTex(self._actorPool, holder)
        local rec = Cat.Get("aa_checkpoint")
        if rec then Cat.ApplyTexture(tex, rec.tex) end
        PlaceFoot(tex, holder, cp.x, cp.y, 24, 48)
        if cp.reached then
            tex:SetVertexColor(1, 1, 1, 1)
        else
            tex:SetVertexColor(0.7, 0.85, 1, 0.75)
        end
    end

    for i = 1, #(gs.enemies or {}) do
        local e = gs.enemies[i]
        if e and not e.dead then
            local tex = AcquireTex(self._actorPool, holder)
            local rec
            if e.role then
                rec = Cat.Get("tr_" .. e.role)
            else
                local id = (e.type == "flyer" and "flyer")
                    or (e.type == "turtle" and "turtle")
                    or (e.type == "shooter" and "shooter")
                    or "walker"
                rec = Cat.Get(id)
            end
            if rec then Cat.ApplyTexture(tex, Cat.ItemTex(rec, game)) end
            PlaceFoot(tex, holder, e.x, e.y, 28, 28)
        end
    end

    for i = 1, #(gs.birds or {}) do
        local b = gs.birds[i]
        if b and not b.dead then
            local tex = AcquireTex(self._actorPool, holder)
            local rec = Cat.Get("tr_bird")
            if rec then Cat.ApplyTexture(tex, rec.tex) end
            PlaceFoot(tex, holder, b.x, b.y + 8, 18, 14)
        end
    end

    for i = 1, #(gs.projectiles or {}) do
        local pr = gs.projectiles[i]
        if pr then
            local tex = AcquireTex(self._actorPool, holder)
            tex:SetTexture(WHITE)
            if pr.kind == "waterblob" then
                tex:SetVertexColor(0.35, 0.75, 1, 1)
            elseif pr.kind == "fountain" then
                tex:SetVertexColor(0.55, 0.9, 1, 0.9)
            elseif pr.kind == "lavablob" then
                tex:SetVertexColor(1, 0.35, 0.08, 1)
            else
                tex:SetVertexColor(1, 0.55, 0.12, 1)
            end
            PlaceCenter(tex, holder, pr.x, pr.y, 12, 12)
        end
    end

    for i = 1, #(gs.coins or {}) do
        local coin = gs.coins[i]
        if coin and not coin.taken then
            local tex = AcquireTex(self._actorPool, holder)
            Cat.ApplyTexture(tex, Cat.Get("coin").tex)
            PlaceFoot(tex, holder, coin.x, coin.y, 22, 22)
        end
    end

    for i = 1, #(gs.pickups or {}) do
        local pu = gs.pickups[i]
        if pu and not pu.taken then
            local tex = AcquireTex(self._actorPool, holder)
            local rec = Cat.Get("tr_pickup")
            if rec then Cat.ApplyTexture(tex, rec.tex) end
            PlaceFoot(tex, holder, pu.x, pu.y, 22, 22)
        end
    end

    if gs.lv and gs.lv.goal then
        local tex = AcquireTex(self._actorPool, holder)
        local rec = Cat.Get("goal")
        Cat.ApplyTexture(tex, Cat.ItemTex(rec, game))
        PlaceFoot(tex, holder, gs.lv.goal.x, gs.lv.goal.y, 32, 64)
    end
end

function LE:_RefreshStatus()
    if not self._statusFS then return end
    local d = self._draft
    local extra = ""
    if self._mode == "play" and self._gs then
        extra = string.format(L("status_play", "  |  PLAY  x=%d y=%d  lives=%d  %s"),
            math.floor(self._gs.player.x), math.floor(self._gs.player.y),
            self._gs.lives, self._gs.state)
        if self._gs.player.hp then
            extra = extra .. string.format(L("status_hp", "  hp=%d"), math.floor(self._gs.player.hp))
        end
    elseif self._brush == "?" then
        extra = string.format(L("status_qblock", "  |  ?-Inhalt: %s"), tostring(self._qContents))
    elseif Catalog().IsPairChar(self._brush, DraftGame()) then
        extra = string.format(L("status_pair", "  |  Roehre/Tuer Paar %s  (S ducken)"), tostring(self._pipePair))
    elseif Catalog().IsMobChar(self._brush, DraftGame()) then
        extra = string.format(L("status_patrol", "  |  Patrol %s  %s"),
            tostring(self._patrol), tostring(self._mobBehavior))
    elseif self._brush == "B" then
        extra = string.format(L("status_boss", "  |  Boss %s"), tostring(self._bossType))
    elseif self._brush == "=" then
        extra = L("status_platform", "  |  Drop-through: S")
    elseif self._brush == "w" or self._brush == "i" then
        extra = L("status_swim", "  |  Schwimmen (W/N toedlich). Wellen nur oben, i/N = tief")
    elseif self._brush == "W" or self._brush == "N" then
        extra = L("status_water", "  |  Toedliches Wasser. Wellen nur an der Oberflaeche")
    elseif self._brush == "L" or self._brush == "l" then
        extra = L("status_lava", "  |  Lava. Wellen nur an der Oberflaeche, l = tief")
    else
        local item = Catalog().ByChar(self._brush, DraftGame())
        if item and item.propKind == "mover" then
            extra = string.format(L("status_mover", "  |  Fahrstuhl %s/%s  (RMB entfernt Prop zuerst)"),
                self._moverAxis or "h", self._moverSpan or "4")
        elseif item and (item.propKind == "lavaemit" or item.propKind == "waterarc") then
            extra = string.format(L("status_arc", "  |  Bogen %s  (RMB entfernt Prop zuerst)"),
                L("emit_" .. (self._emitDir or "u"), self._emitDir or "u"))
        elseif item and item.overlay then
            extra = string.format(L("status_prop", "  |  Prop: %s  (RMB entfernt Prop zuerst)"),
                Catalog().ItemLabel(item))
        end
    end
    local gameTag = (DraftGame() == Catalog().GAME_TR) and L("game_tr", "TR") or L("game_aa", "AA")
    local theme = (d.theme == "night") and L("theme_night", "Nacht") or L("theme_day", "Tag")
    self._statusFS:SetFormattedText(
        L("status_fmt", "  %s  %s  %dx%d  %s  Pinsel [%s]  cam %d,%d  WASD pan  Alt+Ziehen Auswahl  Strg+Z/C/V  Play/Hier%s%s"),
        d.name or "Draft", gameTag, d.width, d.height, theme, self._brush,
        math.floor(self._camX), math.floor(self._camY),
        (DraftGame() == Catalog().GAME_TR) and L("status_fire", "  F Feuer") or "", extra)
end

function LE:_ApplyPaintAtCursor(erase)
    if self._mode ~= "edit" then return end
    local lx, ly = CursorToView()
    local vw, vh = ViewWH()
    if not lx or lx < 0 or ly < 0 or lx > vw or ly > vh then return end
    local col, row = ViewToCell(lx, ly)
    self._hoverCol, self._hoverRow = col, row
    if IsAltKeyDown and IsAltKeyDown() then
        if not self._sel or not self._sel.dragging then
            self._sel = { c0 = col, r0 = row, c1 = col, r1 = row, dragging = true }
        else
            self._sel.c1, self._sel.r1 = col, row
        end
        self._dirty = true
        return
    end
    if not erase and IsShiftKeyDown and IsShiftKeyDown() then
        local kind = Ser().GetProp(self._draft, col, row)
        if kind then
            local rec = Catalog().ByPropKind(kind)
            if rec then
                self._brush = rec.ch
                local recp = Ser().GetPropRecord(self._draft, col, row)
                if recp then
                    if rec.propKind == "mover" or rec.propKind == "wind" then
                        self._moverAxis = recp.axis or "h"
                        self._moverSpan = tostring(recp.span or 4)
                    elseif rec.propKind == "spinner" then
                        self._spinMode = recp.spin or "90"
                    elseif rec.propKind == "camlock" then
                        self._camLock = recp.cam or "xy"
                        self._moverSpan = tostring(recp.span or 4)
                    elseif rec.propKind == "lavaemit" or rec.propKind == "waterarc" then
                        self._emitDir = Catalog().NormalizeEmitDir(recp.dir or "u")
                    end
                end
                self:_HighlightPalette()
                self:_RefreshStatus()
                return
            end
        end
        if Ser().Get(self._draft, col, row) == "?" then
            self._brush = "?"
            self._qContents = Ser().GetBlockContents(self._draft, col, row)
            self:_HighlightPalette()
            if self._contentsDD and self._contentsDD.RefreshDisplay then
                self._contentsDD:RefreshDisplay()
            end
            self:_RefreshStatus()
            return
        end
        if Catalog().IsPairChar(Ser().Get(self._draft, col, row), DraftGame()) then
            local ch = Ser().Get(self._draft, col, row)
            self._brush = ch
            self._pipePair = tostring(Ser().GetPipePair(self._draft, col, row))
            self:_HighlightPalette()
            if self._pipePairDD and self._pipePairDD.RefreshDisplay then
                self._pipePairDD:RefreshDisplay()
            end
            self:_RefreshStatus()
            return
        end
    end
    if erase then
        if Ser().ClearProp(self._draft, col, row) then
            self._dirty = true
            return
        end
    end
    self:_PaintCell(col, row, erase and "." or self._brush)
end

function LE:_EnterPlay(origin)
    local Logic = PlayLogic()
    if not Logic then
        print(L("print_no_logic", "|cffffaa00[LevelEditor]|r Logic nicht geladen."))
        return
    end
    SaveDraft()
    local entry = Ser().ToEntry(self._draft)
    local spawnX, spawnY
    if origin == "cursor" and self._hoverCol and self._hoverRow then
        spawnX = (self._hoverCol - 0.5) * TILE
        spawnY = self._hoverRow * TILE
    elseif origin == "check" then
        for r = 1, self._draft.height do
            for c = 1, self._draft.width do
                if Ser().Get(self._draft, c, r) == "k" then
                    spawnX = (c - 0.5) * TILE
                    spawnY = r * TILE
                    break
                end
            end
            if spawnX then break end
        end
    end
    local gs = Logic:NewBoard({
        entry = entry,
        level = 0,
        difficulty = "normal",
        lives = Logic.START_LIVES,
        score = 0,
        spawnX = spawnX,
        spawnY = spawnY,
    })
    if not gs then
        print(L("print_no_board", "|cffff4444[LevelEditor]|r Playtest-Board konnte nicht gebaut werden."))
        return
    end
    self._gs = gs
    self._mode = "play"
    self._playBtn.text:SetText(L("btn_stop", "Stop"))
    self._dirty = true
    _gameLoop:Start(function(dt) LE:_PlayTick(dt) end, {
        stateCheck = function() return LE._mode == "play" end,
        maxDt = 0.1,
    })
    self:_Redraw()
end

function LE:_ExitPlay()
    _gameLoop:Stop()
    self._gs = nil
    self._mode = "edit"
    if self._playBtn and self._playBtn.text then
        self._playBtn.text:SetText(L("btn_play", "Play"))
    end
    self._dirty = true
    self:_Redraw()
end

function LE:_PlayTick(dt)
    local Logic = PlayLogic()
    local gs = self._gs
    if not gs or self._mode ~= "play" then return end
    if gs.state == "PLAYING" then
        Logic:Update(gs, dt)
        local lv = gs.lv
        local vw, vh = ViewWH()
        local maxCamX = math.max(0, lv.pixelW - vw)
        local maxCamY = math.max(0, lv.pixelH - vh)
        self._camX = math.max(0, math.min(maxCamX, gs.player.x - vw * 0.5))
        self._camY = math.max(0, math.min(maxCamY, gs.player.y - vh * 0.7))
        self._dirty = true
        self:_Redraw()
    else
        self:_RefreshStatus()
    end
end

function LE:_ShowExport()
    SaveDraft()
    local text = Ser().ToLua(self._draft)
    local dlg = self._exportDlg
    if not dlg then
        dlg = CreateFrame("Frame", "ArcadiaNexus_LevelEditorExport", self._frame, "BackdropTemplate")
        dlg:SetSize(720, 420)
        dlg:SetPoint("CENTER")
        dlg:SetFrameStrata("FULLSCREEN_DIALOG")
        dlg:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        dlg:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
        dlg:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)

        local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -12)
        title:SetText(L("export_title", "|cffffd700Lua-Export – markieren und kopieren|r"))

        local scroll = CreateFrame("ScrollFrame", nil, dlg, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -36)
        scroll:SetPoint("BOTTOMRIGHT", -36, 48)

        local eb = CreateFrame("EditBox", nil, scroll)
        eb:SetMultiLine(true)
        eb:SetFontObject(GameFontHighlightSmall)
        eb:SetWidth(650)
        eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function() dlg:Hide() end)
        scroll:SetScrollChild(eb)
        dlg.edit = eb

        local close = UI().CreateArcadiaButton(dlg, L("btn_close", "Schliessen"), 140, 30)
        close:SetPoint("BOTTOM", 0, 10)
        close:SetScript("OnClick", function() dlg:Hide() end)
        self._exportDlg = dlg
    end
    dlg:Show()
    dlg.edit:SetText(text)
    dlg.edit:HighlightText()
    dlg.edit:SetFocus()
end

function LE:_JumpToCell(col, row)
    if not col or not row or not self._draft then return end
    local vw, vh = ViewWH()
    self._camX = (col - 0.5) * TILE - vw * 0.5
    self._camY = (row - 0.5) * TILE - vh * 0.5
    ClampCam()
    self._sel = { c0 = col, r0 = row, c1 = col, r1 = row, dragging = false }
    self._hoverCol, self._hoverRow = col, row
    self._dirty = true
    self:_Redraw()
end

function LE:_ShowValidate()
    if self._mode == "play" then self:_ExitPlay() end
    local report = Ser().Validate(self._draft)
    local dlg = self._validateDlg
    if not dlg then
        dlg = CreateFrame("Frame", "ArcadiaNexus_LevelEditorValidate", self._frame, "BackdropTemplate")
        dlg:SetSize(520, 360)
        dlg:SetPoint("CENTER")
        dlg:SetFrameStrata("FULLSCREEN_DIALOG")
        dlg:EnableMouse(true)
        dlg:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        dlg:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
        dlg:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)

        local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -12)
        dlg.title = title

        local hint = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOP", title, "BOTTOM", 0, -4)
        hint:SetTextColor(0.70, 0.68, 0.55)
        hint:SetText(L("val_hint", "Klick auf eine Zeile springt zur Kachel."))
        dlg.hint = hint

        local scroll = CreateFrame("ScrollFrame", nil, dlg, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -48)
        scroll:SetPoint("BOTTOMRIGHT", -36, 48)
        local child = CreateFrame("Frame", nil, scroll)
        child:SetSize(450, 10)
        scroll:SetScrollChild(child)
        dlg.list = child
        dlg.rows = {}

        local close = UI().CreateArcadiaButton(dlg, L("btn_close", "Schliessen"), 140, 30)
        close:SetPoint("BOTTOM", 0, 10)
        close:SetScript("OnClick", function() dlg:Hide() end)
        self._validateDlg = dlg
    end

    local nErr, nWarn = report.errors or 0, report.warns or 0
    if nErr == 0 and nWarn == 0 then
        dlg.title:SetText(L("val_ok_title", "|cff88ff88Pruefung – keine Probleme|r"))
    else
        dlg.title:SetFormattedText(L("val_title", "|cffffd700Pruefung|r  |cffff6666%d Fehler|r  |cffffcc66%d Hinweise|r"),
            nErr, nWarn)
    end

    local child = dlg.list
    local rows = dlg.rows
    local list = report.issues or {}
    if #list == 0 then
        list = { { sev = "ok", msg = L("val_ok_body", "Spawn, Ziel und Paare sehen in Ordnung aus.") } }
    end
    for i = 1, #list do
        local it = list[i]
        local row = rows[i]
        if not row then
            row = CreateFrame("Button", nil, child)
            row:SetSize(450, 22)
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", 4, 0)
            fs:SetPoint("RIGHT", -4, 0)
            fs:SetJustifyH("LEFT")
            row.fs = fs
            row:SetScript("OnClick", function(self)
                if self._col and self._row then
                    LE:_JumpToCell(self._col, self._row)
                end
            end)
            rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -((i - 1) * 22))
        row._col, row._row = it.col, it.row
        local prefix = (it.sev == "error") and L("sev_error", "|cffff6666Fehler|r  ")
            or (it.sev == "warn") and L("sev_warn", "|cffffcc66Hinweis|r  ")
            or "|cff88ff88OK|r  "
        local where = (it.col and it.row) and string.format("  [%d,%d]", it.col, it.row) or ""
        row.fs:SetText(prefix .. (it.msg or "") .. where)
        row:Show()
    end
    for i = #list + 1, #rows do
        rows[i]:Hide()
    end
    child:SetHeight(math.max(10, #list * 22))
    dlg:Show()

    if nErr == 0 and nWarn == 0 then
        print(L("print_ok", "|cff88ff88[LevelEditor]|r Pruefung ok."))
    else
        print(string.format(L("print_report", "|cffffd700[LevelEditor]|r Pruefung: %d Fehler, %d Hinweise."), nErr, nWarn))
    end
end

function LE:_BuildPalette(parent)
    EnsureGroups()
    local Cat = Catalog()
    local palette = Cat.Palette()

    local inspect = CreateFrame("Frame", nil, parent)
    inspect:SetPoint("TOPLEFT", 8, -6)
    self._inspectFrame = inspect
    inspect:SetPoint("TOPRIGHT", -8, -6)
    inspect:SetHeight(INSPECT_H)
    local inspLbl = inspect:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    inspLbl:SetPoint("TOPLEFT", 0, 0)
    inspLbl:SetText(L("insp_qblock", "|cffffd700?-Inhalt|r"))
    BindLabelTip(inspLbl, inspect, L("insp_qblock_title", "?-Inhalt"),
        L("insp_qblock_body", "Gilt beim Pinsel [?]. Bestimmt, was der Block beim Kopfstoss ausspuckt."))
    local ddHost = CreateFrame("Frame", nil, inspect)
    ddHost:SetSize(PAL_W - 36, 26)
    ddHost:SetPoint("TOPLEFT", 0, -14)
    self._contentsDD = UI().CreateSimpleDropdown(
        ddHost, 0, 0, PAL_W - 40, "",
        Cat.LocalizedOptions(Cat.QBLOCK_CONTENTS, "qblock_"),
        function() return LE._qContents or "random" end,
        function(key)
            LE._qContents = key
            LE:_RefreshStatus()
        end,
        { title = L("dd_qblock_title", "?-Inhalt"), text = L("dd_qblock_text", "Was der naechste ?-Block ausgibt. Gilt beim Platzieren.") }
    )
    local axisLbl = inspect:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    axisLbl:SetPoint("TOPLEFT", 0, -42)
    axisLbl:SetText(L("insp_mover", "|cffffd700Fahrstuhl / Wind / Groesse|r"))
    BindLabelTip(axisLbl, inspect, L("insp_mover_title", "Fahrstuhl / Wind / Groesse"),
        L("insp_mover_body", "Links: Richtung. Rechts: Strecke in Kacheln. Gilt fuer Fahrstuhl, Wind und Kamera-Zone."))
    local axisHost = CreateFrame("Frame", nil, inspect)
    axisHost:SetSize((PAL_W - 44) / 2, 26)
    axisHost:SetPoint("TOPLEFT", 0, -56)
    self._moverAxisDD = UI().CreateSimpleDropdown(
        axisHost, 0, 0, (PAL_W - 48) / 2, "",
        Cat.LocalizedOptions(Cat.MOVER_AXES, "axis_"),
        function() return LE._moverAxis or "h" end,
        function(key)
            LE._moverAxis = key
            LE:_RefreshStatus()
        end,
        { title = L("dd_axis_title", "Richtung"), text = L("dd_axis_text", "Fahrstuhl und Wind: horizontal oder vertikal.") }
    )
    local spanHost = CreateFrame("Frame", nil, inspect)
    spanHost:SetSize((PAL_W - 44) / 2, 26)
    spanHost:SetPoint("TOPLEFT", axisHost, "TOPRIGHT", 6, 0)
    self._moverSpanDD = UI().CreateSimpleDropdown(
        spanHost, 0, 0, (PAL_W - 48) / 2, "",
        Cat.LocalizedOptions(Cat.MOVER_SPANS, "span_"),
        function() return LE._moverSpan or "4" end,
        function(key)
            LE._moverSpan = key
            LE:_RefreshStatus()
        end,
        { title = L("dd_span_title", "Strecke / Groesse"), text = L("dd_span_text", "Fahrstuhl-Weg in Tiles. Bei Wind und Kamera-Zone die Ausdehnung.") }
    )
    local pipeLbl = inspect:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pipeLbl:SetPoint("TOPLEFT", 0, -84)
    pipeLbl:SetText(L("insp_pair", "|cffffd700Paar (Rohr / Tuer)|r"))
    BindLabelTip(pipeLbl, inspect, L("insp_pair_title", "Paar"),
        L("insp_pair_body", "Gleiche Nummer: zwei Roehren warp-en, oder Schalter oeffnet die Tuer / der Schluessel passt."))
    local pipeHost = CreateFrame("Frame", nil, inspect)
    pipeHost:SetSize(PAL_W - 36, 26)
    pipeHost:SetPoint("TOPLEFT", 0, -98)
    self._pipePairDD = UI().CreateSimpleDropdown(
        pipeHost, 0, 0, PAL_W - 40, "",
        Cat.LocalizedOptions(Cat.PIPE_PAIRS, "pair_", "pair_tip"),
        function() return LE._pipePair or "1" end,
        function(key)
            LE._pipePair = key
            LE:_RefreshStatus()
        end,
        { title = L("dd_pair_title", "Paar-Nummer"), text = L("dd_pair_text", "Roehre I, Schalter s, Tuer D und Schluessel U mit derselben Nummer gehoeren zusammen.") }
    )

    local spinLbl = inspect:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spinLbl:SetPoint("TOPLEFT", 0, -126)
    spinLbl:SetText(L("insp_spin", "|cffffd700Dreh-Plattform|r"))
    BindLabelTip(spinLbl, inspect, L("insp_spin_title", "Dreh-Plattform"),
        L("insp_spin_body", "Gilt beim Overlay [r]: 90 Grad kippen oder 360 Grad drehen."))
    local spinHost = CreateFrame("Frame", nil, inspect)
    spinHost:SetSize(PAL_W - 36, 26)
    spinHost:SetPoint("TOPLEFT", 0, -140)
    self._spinModeDD = UI().CreateSimpleDropdown(
        spinHost, 0, 0, PAL_W - 40, "",
        Cat.LocalizedOptions(Cat.SPIN_MODES, "spin_"),
        function() return LE._spinMode or "90" end,
        function(key)
            LE._spinMode = key
            LE:_RefreshStatus()
        end,
        { title = L("dd_spin_title", "Dreh-Modus"), text = L("dd_spin_text", "90 Grad: kippen und halten. 360 Grad: dauernd drehen.") }
    )

    local emitLbl = inspect:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    emitLbl:SetPoint("TOPLEFT", 0, -168)
    emitLbl:SetText(L("insp_emit", "|cffffd700Schussrichtung|r"))
    BindLabelTip(emitLbl, inspect, L("insp_emit_title", "Schussrichtung"),
        L("insp_emit_body", "Gilt fuer Lava-Schuss [h] (toetet) und Wasser-Schuss [v] (stosst weg). Senkrecht = hoch und zurueck."))
    local emitHost = CreateFrame("Frame", nil, inspect)
    emitHost:SetSize(PAL_W - 36, 26)
    emitHost:SetPoint("TOPLEFT", 0, -182)
    self._emitDirDD = UI().CreateSimpleDropdown(
        emitHost, 0, 0, PAL_W - 40, "",
        Cat.LocalizedOptions(Cat.EMIT_DIRS, "edir_"),
        function() return LE._emitDir or "u" end,
        function(key)
            LE._emitDir = key
            LE:_RefreshStatus()
        end,
        { title = L("dd_emit_title", "Schussrichtung"), text = L("dd_emit_text", "Senkrecht, Bogen rechts oder Bogen links. Lava-Schuss toetet, Wasser-Schuss stosst.") }
    )

    local extraLbl = inspect:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    extraLbl:SetPoint("TOPLEFT", 0, -208)
    extraLbl:SetText(L("insp_extra", "|cffffd700Patrol / Kamera / Boss|r"))
    BindLabelTip(extraLbl, inspect, L("insp_extra_title", "Patrol / Kamera / Boss"),
        L("insp_extra_body", "Gegner-Weg und Kanten-Verhalten, Kamera-Zone, Boss-Typ fuer Marker B."))
    local patHost = CreateFrame("Frame", nil, inspect)
    patHost:SetSize((PAL_W - 44) / 2, 26)
    patHost:SetPoint("TOPLEFT", 0, -222)
    self._patrolDD = UI().CreateSimpleDropdown(
        patHost, 0, 0, (PAL_W - 48) / 2, "",
        Cat.LocalizedOptions(Cat.ENEMY_PATROLS, "patrol_"),
        function() return LE._patrol or "4" end,
        function(key)
            LE._patrol = key
            LE:_RefreshStatus()
        end,
        { title = L("dd_patrol_title", "Patrol"), text = L("dd_patrol_text", "Wie weit Walker, Schildkroete, Flieger oder Schuetze um den Spawn laufen.") }
    )
    local behHost = CreateFrame("Frame", nil, inspect)
    behHost:SetSize((PAL_W - 44) / 2, 26)
    behHost:SetPoint("TOPLEFT", patHost, "TOPRIGHT", 6, 0)
    self._mobBehDD = UI().CreateSimpleDropdown(
        behHost, 0, 0, (PAL_W - 48) / 2, "",
        Cat.LocalizedOptions(Cat.MOB_BEHAVIORS, "beh_"),
        function() return LE._mobBehavior or "turn" end,
        function(key)
            LE._mobBehavior = key
            LE:_RefreshStatus()
        end,
        { title = L("dd_edge_title", "Kante"), text = L("dd_edge_text", "Was der Gegner am Abgrund macht: umdrehen, warten oder weiterlaufen.") }
    )
    local camHost = CreateFrame("Frame", nil, inspect)
    camHost:SetSize((PAL_W - 44) / 2, 26)
    camHost:SetPoint("TOPLEFT", 0, -250)
    self._camLockDD = UI().CreateSimpleDropdown(
        camHost, 0, 0, (PAL_W - 48) / 2, "",
        Cat.LocalizedOptions(Cat.CAM_LOCKS, "cam_"),
        function() return LE._camLock or "xy" end,
        function(key)
            LE._camLock = key
            LE:_RefreshStatus()
        end,
        { title = L("dd_cam_title", "Kamera-Zone"), text = L("dd_cam_text", "Gilt beim Overlay [Z]. Sperrt Scrollen in X, Y oder beides.") }
    )
    local bossHost = CreateFrame("Frame", nil, inspect)
    bossHost:SetSize((PAL_W - 44) / 2, 26)
    bossHost:SetPoint("TOPLEFT", camHost, "TOPRIGHT", 6, 0)
    self._bossDD = UI().CreateSimpleDropdown(
        bossHost, 0, 0, (PAL_W - 48) / 2, "",
        Cat.LocalizedOptions(Cat.BOSS_TYPES, "boss_"),
        function() return LE._bossType or "golem" end,
        function(key)
            LE._bossType = key
            LE:_RefreshStatus()
        end,
        { title = L("dd_boss_title", "Boss-Typ"), text = L("dd_boss_text", "Welcher Boss am Marker [B] erscheint. Nur Azeroth Ascent.") }
    )

    local scroll = CreateFrame("ScrollFrame", "ArcadiaNexus_LevelEditorPalScroll", parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -(INSPECT_H + 10))
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(range, cur - delta * 36)))
    end)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(PAL_W - 40)
    child:SetHeight(10)
    scroll:SetScrollChild(child)
    self._palScroll = scroll
    self._palChild = child

    local groups, order, seen = {}, {}, {}
    for i = 1, #palette do
        local item = palette[i]
        local gid = item.group or "other"
        if not seen[gid] then
            seen[gid] = { id = gid, items = {} }
            order[#order + 1] = seen[gid]
        end
        seen[gid].items[#seen[gid].items + 1] = item
    end
    self._paletteGroups = order
    self._paletteItems = palette

    for g = 1, #order do
        local grp = order[g]
        local header = CreateFrame("Button", nil, child)
        header:SetSize(PAL_W - 42, 22)
        local hbg = header:CreateTexture(nil, "BACKGROUND")
        hbg:SetAllPoints()
        hbg:SetTexture(WHITE)
        hbg:SetVertexColor(0.18, 0.16, 0.10, 0.95)
        local hfs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hfs:SetPoint("LEFT", 6, 0)
        hfs:SetJustifyH("LEFT")
        header._label = hfs
        header._gid = grp.id
        header:SetScript("OnClick", function()
            EnsureGroups()
            LE._groupOpen[grp.id] = not (LE._groupOpen[grp.id] ~= false)
            LE:_LayoutPalette()
            SaveDraft()
        end)
        grp.header = header
        grp.rows = {}
        for i = 1, #grp.items do
            local item = grp.items[i]
            local btn = CreateFrame("Button", nil, child)
            btn._item = item
            btn:SetSize(PAL_W - 42, 26)
            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture(WHITE)
            bg:SetVertexColor(0.12, 0.12, 0.16, 0.9)
            btn._bg = bg
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(22, 22)
            icon:SetPoint("LEFT", 4, 0)
            if item.tex then
                Cat.ApplyTexture(icon, Cat.ItemTex(item, DraftGame()) or item.tex)
            else
                icon:SetTexture(WHITE)
                icon:SetVertexColor(0.2, 0.2, 0.25, 1)
            end
            local lab = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lab:SetPoint("LEFT", icon, "RIGHT", 6, 0)
            lab:SetText(string.format("[%s]  %s", item.ch, Cat.ItemLabel(item)))
            btn:SetScript("OnClick", function()
                LE._brush = item.ch
                LE:_HighlightPalette()
                LE:_RefreshStatus()
            end)
            btn._ch = item.ch
            item._btn = btn
            grp.rows[#grp.rows + 1] = btn
        end
    end
    self:_LayoutPalette()
    self:_HighlightPalette()
end

function LE:_LayoutPalette()
    EnsureGroups()
    local Cat = Catalog()
    local child = self._palChild
    local groups = self._paletteGroups
    if not child or not groups then return end
    local y = 0
    local game = DraftGame()
    for g = 1, #groups do
        local grp = groups[g]
        local open = self._groupOpen[grp.id] ~= false
        local visible = 0
        for i = 1, #grp.rows do
            local item = grp.rows[i]._item
            if item and Cat.Allowed(item, game) then
                visible = visible + 1
            end
        end
        if visible == 0 then
            grp.header:Hide()
            for i = 1, #grp.rows do grp.rows[i]:Hide() end
        else
            grp.header:Show()
            grp.header:ClearAllPoints()
            grp.header:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
            grp.header._label:SetText(string.format("%s  %s",
                open and "-" or "+", Cat.GroupLabel(grp.id)))
            y = y + 24
            for i = 1, #grp.rows do
                local btn = grp.rows[i]
                local item = btn._item
                if item and Cat.Allowed(item, game) and open then
                    btn:Show()
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
                    y = y + 28
                else
                    btn:Hide()
                end
            end
            y = y + 4
        end
    end
    child:SetHeight(math.max(y, 1))
    if self._palScroll then
        local range = self._palScroll:GetVerticalScrollRange() or 0
        local cur = self._palScroll:GetVerticalScroll() or 0
        if cur > range then
            self._palScroll:SetVerticalScroll(range)
        end
    end
end

function LE:_RefreshInspectState()
    local b = self._brush
    local Cat = Catalog()
    local game = DraftGame()
    local function setDD(dd, on)
        if dd and dd.SetEnabled then dd:SetEnabled(on) end
        if dd and dd.RefreshDisplay then dd:RefreshDisplay() end
    end
    setDD(self._contentsDD, b == "?")
    setDD(self._moverAxisDD, b == "m" or b == "y")
    setDD(self._moverSpanDD, b == "m" or b == "y" or b == "Z")
    setDD(self._pipePairDD, Cat.IsPairChar(b, game))
    setDD(self._spinModeDD, b == "r")
    setDD(self._emitDirDD, Cat.IsEmitArcItem(Cat.ByChar(b, game)))
    setDD(self._patrolDD, Cat.IsMobChar(b, game))
    setDD(self._mobBehDD, Cat.IsMobChar(b, game))
    setDD(self._camLockDD, b == "Z")
    setDD(self._bossDD, b == "B")
end

function LE:_HighlightPalette()
    local items = self._paletteItems
    if not items then return end
    for i = 1, #items do
        local btn = items[i]._btn
        if btn and btn._bg then
            if items[i].ch == self._brush then
                btn._bg:SetVertexColor(0.45, 0.35, 0.10, 1)
            else
                btn._bg:SetVertexColor(0.12, 0.12, 0.16, 0.9)
            end
        end
    end
    self:_RefreshInspectState()
end

function LE:_ApplyViewSky()
    local view = self._view
    if not view or not view.SetBackdropColor then return end
    local d = self._draft
    local key = Catalog().NormalizeParallax(d and d.parallax)
    local theme = d and d.theme
    local r, g, b = 0.10, 0.14, 0.22
    if key == "cave" then
        r, g, b = 0.07, 0.06, 0.08
    elseif key == "lava" then
        r, g, b = 0.22, 0.08, 0.04
    elseif key == "storm" or (key == "theme" and theme == "night") or (key == "clear" and theme == "night") then
        r, g, b = 0.06, 0.07, 0.14
    elseif key == "clear" then
        r, g, b = 0.14, 0.18, 0.28
    end
    view:SetBackdropColor(r, g, b, 1)
end

function LE:_CycleParallax()
    if self._mode == "play" or not self._draft then return end
    if DraftGame() == Catalog().GAME_TR then return end
    self._draft.parallax = Catalog().NextParallax(self._draft.parallax)
    self:_RefreshSizeLabel()
    self:_ApplyViewSky()
    self:_Redraw()
    SaveDraft()
end

function LE:_RefreshSizeLabel()
    if not self._draft then return end
    if self._sizeFS then
        self._sizeFS:SetFormattedText(L("size_fmt", "%d × %d  %s  Px %s"),
            self._draft.width, self._draft.height,
            (self._draft.theme == "night") and L("theme_night", "Nacht") or L("theme_day", "Tag"),
            Catalog().ParallaxLabel(self._draft.parallax))
    end
    if self._themeBtn and self._themeBtn.text then
        self._themeBtn.text:SetText((self._draft.theme == "night") and L("theme_night", "Nacht") or L("theme_day", "Tag"))
    end
    if self._pxBtn and self._pxBtn.text then
        self._pxBtn.text:SetText(Catalog().ParallaxLabel(self._draft.parallax))
    end
    if self._gameBtn and self._gameBtn.text then
        self._gameBtn.text:SetText((DraftGame() == Catalog().GAME_TR) and L("game_tr", "TR") or L("game_aa", "AA"))
    end
end

function LE:_ApplyGameChrome()
    local tr = DraftGame() == Catalog().GAME_TR
    if self._inspectFrame then
        self._inspectFrame:SetShown(not tr)
    end
    if self._palScroll then
        self._palScroll:ClearAllPoints()
        local parent = self._palScroll:GetParent()
        if parent then
            self._palScroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, tr and -6 or -(INSPECT_H + 10))
            self._palScroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -28, 6)
        end
    end
    if self._aaLevelHost then self._aaLevelHost:SetShown(not tr) end
    if self._trLevelHost then self._trLevelHost:SetShown(tr) end
    if self._pxBtn then self._pxBtn:SetShown(not tr) end
    self:_RefreshSizeLabel()
    self:_ApplyViewSky()
end

function LE:_SetGame(game)
    if not self._draft then return end
    if self._mode == "play" then self:_ExitPlay() end
    local Cat = Catalog()
    game = Cat.NormalizeGame(game)
    self._draft.game = game
    local item = Cat.ByChar(self._brush, game)
    if not item or not Cat.Allowed(item, game) then
        self._brush = "#"
    end
    self:_ApplyGameChrome()
    self:_LayoutPalette()
    self:_HighlightPalette()
    self._dirty = true
    self:_Redraw()
    SaveDraft()
end

function LE:_ResizeBy(dw, dh)
    if self._mode == "play" or not self._draft then return end
    local d = self._draft
    if Ser().Resize(d, d.width + (dw or 0), d.height + (dh or 0)) then
        ClampCam()
        self._dirty = true
        self:_RefreshSizeLabel()
        self:_Redraw()
        SaveDraft()
    end
end

function LE:_FitWindow()
    local f = self._frame
    if not f then return end
    local pw = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1280
    local ph = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 800
    local w = math.min(1560, math.max(1180, pw - 48))
    local h = math.min(960, math.max(740, ph - 48))
    if w > pw - 24 then w = math.max(980, pw - 24) end
    if h > ph - 24 then h = math.max(640, ph - 24) end
    f:SetSize(w, h)
end

function LE:_BuildWindow()
    if self._frame then return end
    local f, reused = UI().AcquireNamedFrame("Frame", "ArcadiaNexus_LevelEditor", UIParent, "BackdropTemplate")
    self._frame = f
    self:_FitWindow()
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:EnableKeyboard(true)
    f:SetPropagateKeyboardInput(true)
    if not reused then
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0.04, 0.04, 0.07, 0.96)
        f:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)
    end
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnShow", function(self)
        self:EnableKeyboard(true)
        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(true)
        end
        LE:_FitWindow()
        LE:_LayoutPalette()
    end)
    f:SetScript("OnHide", function()
        LE:_ExitPlay()
        SaveDraft()
    end)
    f:SetScript("OnKeyDown", function(_, key)
        LE:_OnKeyDown(key)
    end)
    f:SetScript("OnKeyUp", function(_, key)
        LE:_OnKeyUp(key)
    end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -12)
        title:SetText(L("title", "|cffffd700Platformer Level-Editor|r  |cffaaaaaaPhase 15|r"))

    local close = UI().CreateArcadiaButton(f, "X", 28, 28)
    close:SetPoint("TOPRIGHT", -10, -8)
    close:SetScript("OnClick", function() f:Hide() end)

    local play = UI().CreateArcadiaButton(f, L("btn_play", "Play"), 90, 28)
    play:SetPoint("TOPRIGHT", close, "TOPLEFT", -8, 0)
    play:SetScript("OnClick", function()
        if LE._mode == "play" then LE:_ExitPlay() else LE:_EnterPlay() end
    end)
    self._playBtn = play

    local hier = UI().CreateArcadiaButton(f, L("btn_here", "Hier"), 70, 28)
    hier:SetPoint("TOPRIGHT", play, "TOPLEFT", -8, 0)
    hier:SetScript("OnClick", function()
        if LE._mode == "play" then LE:_ExitPlay() else LE:_EnterPlay("cursor") end
    end)

    local demo = UI().CreateArcadiaButton(f, L("btn_demo", "Demo"), 70, 28)
    demo:SetPoint("TOPRIGHT", hier, "TOPLEFT", -8, 0)
    demo:SetScript("OnClick", function()
        if LE._mode == "play" then LE:_ExitPlay() end
        local Sample = ArcadiaNexus.LevelEditorSample
        if Sample and Sample.Showcase then
            PushUndo()
            LE._draft = Ser().FromMapString(Sample.Showcase())
            LE._camX, LE._camY = 0, 0
            LE:_SetGame(Catalog().GAME_AA)
            LE._dirty = true
            LE:_Redraw()
            SaveDraft()
        end
    end)

    local exp = UI().CreateArcadiaButton(f, L("btn_export", "Export"), 90, 28)
    exp:SetPoint("TOPRIGHT", demo, "TOPLEFT", -8, 0)
    exp:SetScript("OnClick", function()
        if LE._mode == "play" then LE:_ExitPlay() end
        LE:_ShowExport()
    end)

    local neu = UI().CreateArcadiaButton(f, L("btn_new", "Neu"), 70, 28)
    neu:SetPoint("TOPRIGHT", exp, "TOPLEFT", -8, 0)
    neu:SetScript("OnClick", function()
        if LE._mode == "play" then LE:_ExitPlay() end
        PushUndo()
        LE._draft = Ser().Blank(LE._draft.width, LE._draft.height)
        LE._camX, LE._camY = 0, 0
        LE._dirty = true
        LE:_Redraw()
        LE:_RefreshSizeLabel()
        SaveDraft()
    end)

    local check = UI().CreateArcadiaButton(f, L("btn_check", "Pruefen"), 90, 28)
    check:SetPoint("TOPRIGHT", neu, "TOPLEFT", -8, 0)
    check:SetScript("OnClick", function()
        LE:_ShowValidate()
    end)

    local pal = CreateFrame("Frame", nil, f, "BackdropTemplate")
    pal:SetPoint("TOPLEFT", 8, -TOOL_H - 4)
    pal:SetPoint("BOTTOMLEFT", 8, STATUS_H + 4)
    pal:SetWidth(PAL_W)
    pal:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    pal:SetBackdropColor(0.06, 0.06, 0.09, 0.9)
    pal:SetBackdropBorderColor(0.45, 0.40, 0.25, 1)
    self:_BuildPalette(pal)

    local view = CreateFrame("Frame", nil, f, "BackdropTemplate")
    view:SetPoint("TOPLEFT", pal, "TOPRIGHT", 8, 0)
    view:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, STATUS_H + 4)
    view:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    view:SetBackdropColor(0.10, 0.14, 0.22, 1)
    view:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)
    view:SetClipsChildren(true)
    view:EnableMouse(true)
    view:SetScript("OnMouseDown", function(_, btn)
        if LE._mode == "play" then return end
        if btn == "MiddleButton" then
            local lx, ly = CursorToView()
            LE._panning = true
            LE._panStartX, LE._panStartY = lx or 0, ly or 0
            LE._panCamX, LE._panCamY = LE._camX, LE._camY
        elseif btn == "LeftButton" then
            LE._paintBtn = "LeftButton"
            if not (IsAltKeyDown and IsAltKeyDown()) then
                PushUndo()
            end
            LE:_ApplyPaintAtCursor(false)
            LE:_Redraw()
        elseif btn == "RightButton" then
            LE._paintBtn = "RightButton"
            LE:_ApplyPaintAtCursor(true)
            LE:_Redraw()
        end
    end)
    view:SetScript("OnMouseUp", function()
        LE._paintBtn = nil
        LE._panning = false
        if LE._sel then LE._sel.dragging = false end
    end)
    view:SetScript("OnUpdate", function(_, elapsed)
        if LE._mode ~= "edit" then return end
        LE._animT = (LE._animT or 0) + (elapsed or 0)
        if not LE._panning and not LE._paintBtn
            and (LE._animT - (LE._lastAnimRedraw or 0)) >= 0.12 then
            LE._lastAnimRedraw = LE._animT
            LE:_Redraw()
        end
        if LE._panning then
            local lx, ly = CursorToView()
            if lx then
                LE._camX = LE._panCamX - (lx - LE._panStartX)
                LE._camY = LE._panCamY - (ly - LE._panStartY)
                ClampCam()
                LE._dirty = true
                LE:_Redraw()
            end
        elseif LE._paintBtn then
            LE:_ApplyPaintAtCursor(LE._paintBtn == "RightButton")
            if LE._dirty then LE:_Redraw() end
        end
    end)
    self._view = view

    local holder = CreateFrame("Frame", nil, view)
    holder:SetPoint("TOPLEFT")
    self._holder = holder

    local gridHint = view:CreateTexture(nil, "BACKGROUND")
    gridHint:SetAllPoints()
    gridHint:SetTexture(WHITE)
    gridHint:SetVertexColor(0.08, 0.11, 0.18, 1)

    local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", 12, 8)
    status:SetPoint("BOTTOMRIGHT", -12, 8)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.75, 0.72, 0.60)
    self._statusFS = status

    if ArcadiaNexus.AA_Levels then
        local opts = { {
            key = "0",
            label = L("dd_current_draft", "Aktueller Draft"),
            tooltip = L("dd_current_tip", "Laesst den Draft, den du gerade zeichnest. Laedt kein Kampagnen-Level."),
        } }
        for i = 1, ArcadiaNexus.AA_Levels.MAX_LEVEL do
            local e = ArcadiaNexus.AA_Levels.Get(i)
            opts[#opts + 1] = {
                key = tostring(i),
                label = string.format(L("dd_aa_level", "AA %d  %s"), i, e and e.name or ""),
                tooltip = L("dd_aa_level_tip", "Laedt dieses Kampagnen-Level als Draft. Schreibt nicht nach Levels.lua."),
            }
        end
        local ddHost = CreateFrame("Frame", nil, f)
        ddHost:SetSize(220, 28)
        ddHost:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        self._aaLevelHost = ddHost
        UI().CreateSimpleDropdown(ddHost, 0, 0, 220, "", opts,
            function() return "0" end,
            function(key)
                local idx = tonumber(key)
                if idx and idx > 0 then
                    local e = ArcadiaNexus.AA_Levels.Get(idx)
                    if e then
                        if LE._mode == "play" then LE:_ExitPlay() end
                        LE._draft = Ser().FromMapString(e)
                        LE._draft.game = Catalog().GAME_AA
                        LE._camX, LE._camY = 0, 0
                        LE:_SetGame(Catalog().GAME_AA)
                    end
                end
            end,
            { title = L("dd_aa_title", "Azeroth Ascent"), text = L("dd_aa_text", "Kampagnen-Level als Draft laden. Export bleibt Copy-Paste, Levels.lua wird nicht ueberschrieben.") })
    end

    if ArcadiaNexus.TR_Levels then
        local opts = { {
            key = "0",
            label = L("dd_current_draft", "Aktueller Draft"),
            tooltip = L("dd_current_tip", "Laesst den Draft, den du gerade zeichnest. Laedt kein Kampagnen-Level."),
        } }
        local maxLv = ArcadiaNexus.TR_Levels.MAX_LEVEL or #ArcadiaNexus.TR_Levels.LIST
        for i = 1, maxLv do
            local e = ArcadiaNexus.TR_Levels.Get(i)
            opts[#opts + 1] = {
                key = tostring(i),
                label = string.format(L("dd_tr_level", "TR %d  %s"), i, e and (e.nameKey or e.name) or ""),
                tooltip = L("dd_tr_level_tip", "Laedt dieses Tinker's-Revenge-Level als Draft. Feature-Stand ist noch nicht AA."),
            }
        end
        local ddHost = CreateFrame("Frame", nil, f)
        ddHost:SetSize(220, 28)
        ddHost:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        self._trLevelHost = ddHost
        UI().CreateSimpleDropdown(ddHost, 0, 0, 220, "", opts,
            function() return "0" end,
            function(key)
                local idx = tonumber(key)
                if idx and idx > 0 then
                    local e = ArcadiaNexus.TR_Levels.Get(idx)
                    if e then
                        if LE._mode == "play" then LE:_ExitPlay() end
                        local packed = {
                            name = e.nameKey or e.name or "TR",
                            width = e.width, height = e.height,
                            theme = e.theme or "day", boss = e.boss,
                            game = Catalog().GAME_TR, map = e.map,
                        }
                        LE._draft = Ser().FromMapString(packed)
                        LE._draft.game = Catalog().GAME_TR
                        LE._camX, LE._camY = 0, 0
                        LE:_SetGame(Catalog().GAME_TR)
                    end
                end
            end,
            { title = L("dd_tr_title", "Tinker's Revenge"), text = L("dd_tr_text", "Kampagnen-Level als Draft laden. TR hat noch nicht den AA-Physik-Stand.") })
        ddHost:Hide()
    end

    local sizeHost = CreateFrame("Frame", nil, f)
    sizeHost:SetSize(540, 28)
    sizeHost:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 230, -6)
    local function mini(parent, label, x, fn, w)
        local b = UI().CreateArcadiaButton(parent, label, w or 36, 26)
        b:SetPoint("LEFT", parent, "LEFT", x, 0)
        b:SetScript("OnClick", fn)
        return b
    end
    self._gameBtn = mini(sizeHost, L("game_aa", "AA"), 0, function()
        if LE._mode == "play" or not LE._draft then return end
        local Cat = Catalog()
        LE:_SetGame(DraftGame() == Cat.GAME_TR and Cat.GAME_AA or Cat.GAME_TR)
    end, 40)
    mini(sizeHost, "W-", 46, function() LE:_ResizeBy(-10, 0) end)
    mini(sizeHost, "W+", 84, function() LE:_ResizeBy(10, 0) end)
    mini(sizeHost, "H-", 126, function() LE:_ResizeBy(0, -4) end)
    mini(sizeHost, "H+", 164, function() LE:_ResizeBy(0, 4) end)
    self._themeBtn = mini(sizeHost, L("theme_day", "Tag"), 208, function()
        if LE._mode == "play" or not LE._draft then return end
        LE._draft.theme = (LE._draft.theme == "night") and "day" or "night"
        LE:_RefreshSizeLabel()
        LE:_ApplyViewSky()
        LE:_Redraw()
        SaveDraft()
    end, 48)
    self._pxBtn = mini(sizeHost, "Theme", 260, function()
        LE:_CycleParallax()
    end, 56)
    local sizeFS = sizeHost:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sizeFS:SetPoint("LEFT", sizeHost, "LEFT", 322, 0)
    sizeFS:SetTextColor(0.90, 0.85, 0.70)
    self._sizeFS = sizeFS
    self:_RefreshSizeLabel()
end

function LE:_OnKeyDown(key)
    local f = self._frame
    local ctrl = IsControlKeyDown and IsControlKeyDown()
    if self._mode ~= "play" and ctrl then
        if f then f:SetPropagateKeyboardInput(false) end
        if key == "Z" then
            Undo()
        elseif key == "C" then
            local s = self._sel
            if s then
                self._clip = Ser().CopyRect(self._draft, s.c0, s.r0, s.c1, s.r1)
            elseif self._hoverCol then
                self._clip = Ser().CopyRect(self._draft, self._hoverCol, self._hoverRow, self._hoverCol, self._hoverRow)
            end
        elseif key == "V" then
            if self._clip and self._hoverCol then
                PushUndo()
                Ser().PasteRect(self._draft, self._hoverCol, self._hoverRow, self._clip)
                self._dirty = true
                self:_Redraw()
                SaveDraft()
            end
        elseif key == "P" then
            self:_EnterPlay("cursor")
        elseif key == "K" then
            self:_EnterPlay("check")
        end
        return
    end
    if self._mode == "play" then
        if f and f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(false) end
        local Logic = PlayLogic()
        local gs = self._gs
        if key == "ESCAPE" then
            self:_ExitPlay()
            return
        end
        if not gs or not Logic then return end
        if key == "A" or key == "LEFT" then
            Logic:Press(gs, "left")
        elseif key == "D" or key == "RIGHT" then
            Logic:Press(gs, "right")
        elseif key == "W" or key == "UP" then
            Logic:Press(gs, "up")
        elseif key == "S" or key == "DOWN" then
            Logic:Press(gs, "down")
        elseif key == "SPACE" then
            Logic:QueueJump(gs)
        elseif key == "F" then
            Logic:Press(gs, "fire")
        end
        return
    end

    if key == "ESCAPE" then
        if f and f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(false) end
        f:Hide()
        return
    end

    local pan = TILE
    if key == "A" or key == "LEFT" then
        if f then f:SetPropagateKeyboardInput(false) end
        self._camX = self._camX - pan * 2
        ClampCam(); self:_Redraw()
    elseif key == "D" or key == "RIGHT" then
        if f then f:SetPropagateKeyboardInput(false) end
        self._camX = self._camX + pan * 2
        ClampCam(); self:_Redraw()
    elseif key == "W" or key == "UP" then
        if f then f:SetPropagateKeyboardInput(false) end
        self._camY = self._camY - pan * 2
        ClampCam(); self:_Redraw()
    elseif key == "S" or key == "DOWN" then
        if f then f:SetPropagateKeyboardInput(false) end
        self._camY = self._camY + pan * 2
        ClampCam(); self:_Redraw()
    else
        if f then f:SetPropagateKeyboardInput(true) end
    end
end

function LE:_OnKeyUp(key)
    if self._mode ~= "play" or not self._gs then return end
    local Logic = PlayLogic()
    if not Logic then return end
    if key == "A" or key == "LEFT" then
        Logic:Release(self._gs, "left")
    elseif key == "D" or key == "RIGHT" then
        Logic:Release(self._gs, "right")
    elseif key == "W" or key == "UP" then
        Logic:Release(self._gs, "up")
    elseif key == "S" or key == "DOWN" then
        Logic:Release(self._gs, "down")
    elseif key == "F" then
        Logic:Release(self._gs, "fire")
    elseif key == "SPACE" then
        Logic:Release(self._gs, "jump")
    end
end

function LE.Open()
    if not CanOpen() then
        print(L("print_dev_only", "|cffffaa00[LevelEditor]|r Nur im Developer-Modus (/andevcheck)."))
        return
    end
    if not LE._draft then
        LE._draft = LoadDraft()
        local db = EnsureDB()
        if db then
            LE._camX = db.camX or 0
            LE._camY = db.camY or 0
            LE._brush = db.brush or "#"
            LE._qContents = db.qContents or "random"
            LE._pipePair = db.pipePair or "1"
            LE._emitDir = db.emitDir or "u"
            if type(db.groupOpen) == "table" then
                LE._groupOpen = db.groupOpen
            end
        end
    end
    LE:_BuildWindow()
    EnsureGroups()
    ClampCam()
    LE:_ApplyGameChrome()
    LE._frame:Show()
    LE._frame:Raise()
    LE:_LayoutPalette()
    if LE._contentsDD and LE._contentsDD.RefreshDisplay then
        LE._contentsDD:RefreshDisplay()
    end
    if LE._pipePairDD and LE._pipePairDD.RefreshDisplay then
        LE._pipePairDD:RefreshDisplay()
    end
    if LE._emitDirDD and LE._emitDirDD.RefreshDisplay then
        LE._emitDirDD:RefreshDisplay()
    end
    LE._dirty = true
    LE:_Redraw()
    LE:_HighlightPalette()
end

function LE.Close()
    if LE._frame then LE._frame:Hide() end
end

function LE.Toggle()
    if LE._frame and LE._frame:IsShown() then
        LE.Close()
    else
        LE.Open()
    end
end

SLASH_ANLEVELEDITOR1 = "/anledit"
SLASH_ANLEVELEDITOR2 = "/pledit"
SlashCmdList["ANLEVELEDITOR"] = function()
    LE.Toggle()
end
