-- DevMode route editor for illustrated campaign maps.
-- Drag the ten level nodes, then copy the Lua into the game's CampaignMap.lua.
-- No SavedVariables, no file writes, no sessions, scores or rewards.
local A = ArcadiaNexus
local D = {}
A.CampaignMapDevLayout = D

local X_MIN, X_MAX = 0.06, 0.94
local Y_MIN, Y_MAX = 0.16, 0.84
local VEIL = { "_logoTex", "_logo", "_startBtn", "_slotMenu", "_hintFS", "_campaignMap", "_map", "_runMap" }

local TARGETS = {
    AZEROTHJEWELS = {
        label = "Azeroth Jewels",
        file = "Games/AzerothJewels/CampaignMap.lua",
        pages = function() return A.AJ_CampaignMap and A.AJ_CampaignMap.PAGES end,
    },
    SHADOWSCONQUEST = {
        label = "Shadows Conquest",
        file = "Games/ShadowsConquest/CampaignMap.lua",
        pages = function() return A.SC_CampaignMap and A.SC_CampaignMap.PAGES end,
    },
    BLOCKBREAKER = {
        label = "BlockBreaker",
        file = "Games/BlockBreaker/CampaignMap.lua",
        pages = function() return A.BB_CampaignMap and A.BB_CampaignMap.PAGES end,
    },
}

local function allowed()
    return A.IsDevMode and A.IsDevMode() == true
end

local function de()
    return A.ActiveLocale == "deDE"
end

local function tr(german, english)
    return de() and german or english
end

local function message(text)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ee66Kampagnenkarte:|r " .. text)
    end
end

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function round4(value)
    return math.floor(value * 10000 + 0.5) / 10000
end

local function clamp(value, lo, hi)
    if value < lo then return lo end
    if value > hi then return hi end
    return value
end

local function fmtNum(value)
    local text = string.format("%.4f", value):gsub("0+$", ""):gsub("%.$", "")
    if text == "" or text == "-0" then text = "0" end
    return text
end

local function fmtNodes(nodes)
    local parts = {}
    for i = 1, 10 do
        parts[i] = "{" .. fmtNum(nodes[i][1]) .. "," .. fmtNum(nodes[i][2]) .. "}"
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function copyNodes(pages)
    local out = {}
    for i, page in ipairs(pages) do
        out[i] = {}
        for j = 1, 10 do
            out[i][j] = { page.nodes[j][1], page.nodes[j][2] }
        end
    end
    return out
end

local function validPages(pages)
    if type(pages) ~= "table" or #pages < 1 then return false end
    for _, page in ipairs(pages) do
        if type(page) ~= "table" or type(page.texture) ~= "string" or type(page.nodes) ~= "table" or #page.nodes ~= 10 then
            return false
        end
        for i = 1, 10 do
            local node = page.nodes[i]
            if type(node) ~= "table" or not finite(node[1]) or not finite(node[2]) then return false end
        end
    end
    return true
end

local function label(parent, text, x, y, width, height)
    local font = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    font:SetSize(width or 290, height or 16)
    font:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    font:SetJustifyH("LEFT")
    font:SetText(text)
    return font
end

local function window(name, width, height)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(width, height)
    frame:SetPoint("LEFT", UIParent, "LEFT", 24, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(200)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0.025, 0.035, 0.025, 0.97)
    frame:Hide()
    return frame
end

local function button(parent, text, width, x, y, fn)
    local widget = A.UI.CreateArcadiaButton(parent, text, width, 22)
    widget:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    widget:SetScript("OnClick", fn)
    return widget
end

function D:ContextOk()
    if not allowed() or not self.gameId then return false end
    local state = _G.NexusTabState
    if not state or state.activeCategory ~= self.gameId then return false end
    local registry = A.GameRegistry
    if not registry then return false end
    local container = registry.GetContainer(self.gameId)
    if not container or not container.IsShown or not container:IsShown() then return false end
    local engine = registry.GetEngine(self.gameId)
    if not engine or engine.state ~= "IDLE" then return false end
    return self.renderer and self.renderer._canvas
end

function D:IsEditable()
    return self.active == true and self:ContextOk()
end

function D:Panel()
    local map = self.map
    return map and map._tiles and map._tiles[1] and map._tiles[1]:GetParent()
end

function D:CursorNorm()
    local panel = self:Panel()
    if not panel or not GetCursorPosition or not panel.GetLeft then return nil end
    local scale = panel.GetEffectiveScale and panel:GetEffectiveScale() or 1
    if not finite(scale) or scale == 0 then scale = 1 end
    local x, y = GetCursorPosition()
    local left, top = panel:GetLeft(), panel:GetTop()
    local width, height = panel:GetWidth(), panel:GetHeight()
    if not finite(x) or not finite(y) or not finite(left) or not finite(top) then return nil end
    if not finite(width) or not finite(height) or width <= 0 or height <= 0 then return nil end
    return (x / scale - left) / width, (top - y / scale) / height
end

local function focused(box)
    return box and box.HasFocus and box:HasFocus()
end

function D:Veil()
    local renderer = self.renderer
    if not renderer then return end
    self._veiled = self._veiled or {}
    for _, key in ipairs(VEIL) do
        local widget = renderer[key]
        if widget and widget.Hide and widget ~= self.map then
            if self._veiled[key] == nil and widget.IsShown then
                self._veiled[key] = widget:IsShown() == true
            end
            widget:Hide()
        end
    end
end

function D:RestoreVeil(renderer)
    local veiled = self._veiled
    self._veiled = nil
    if not veiled or not renderer then return end
    for key, wasShown in pairs(veiled) do
        local widget = renderer[key]
        if wasShown and widget and widget.Show and widget ~= self.map then widget:Show() end
    end
end

function D:Sync()
    if not self.map or not self.pages then return end
    local page = self.map:GetPage()
    local nodes = self.pages[page] and self.pages[page].nodes
    local node = nodes and nodes[self.selected or 1]
    self.pageLabel:SetText(string.format("%d / %d", page, self.map:GetPageCount()))
    self.nodeLabel:SetText(tr("Knoten ", "Node ") .. tostring(self.selected or 1))
    if node then
        if not focused(self.xBox) then self.xBox:SetText(fmtNum(node[1])) end
        if not focused(self.yBox) then self.yBox:SetText(fmtNum(node[2])) end
    end
    for i, handle in ipairs(self.handles or {}) do
        local selected = i == self.selected
        handle._tint:SetColorTexture(selected and 0.25 or 0.08, selected and 1 or 0.55, 0.28, selected and 0.28 or 0.08)
        handle._border:SetColorTexture(0.2, 1, 0.35, selected and 0.95 or 0.45)
    end
end

function D:Select(index)
    if not self:IsEditable() then return false end
    index = math.floor(tonumber(index) or 0)
    if index < 1 or index > 10 then return false end
    self.drag = nil
    self.selected = index
    self:Sync()
    return true
end

function D:SetNode(index, x, y)
    if not self:IsEditable() then return false end
    index = math.floor(tonumber(index) or 0)
    if index < 1 or index > 10 or not finite(x) or not finite(y) then return false end
    if x < X_MIN or x > X_MAX or y < Y_MIN or y > Y_MAX then return false end
    x, y = round4(x), round4(y)
    if x < X_MIN or x > X_MAX or y < Y_MIN or y > Y_MAX then return false end
    local page = self.pages[self.map:GetPage()]
    local node = page and page.nodes and page.nodes[index]
    if not node then return false end
    node[1], node[2] = x, y
    self.selected = index
    self.map:Refresh()
    self:Sync()
    return true
end

function D:MoveSelectedToCursor()
    local x, y = self:CursorNorm()
    if not x then return false end
    return self:SetNode(self.selected, clamp(x, X_MIN, X_MAX), clamp(y, Y_MIN, Y_MAX))
end

function D:BeginDrag(index)
    if index then self:Select(index) end
    if not self:IsEditable() or not self.selected then return false end
    self.drag = true
    return self:MoveSelectedToCursor()
end

function D:SetPage(page)
    if not self:IsEditable() or not self.map then return false end
    self.drag = nil
    self.map:SetPage(page)
    self.seenPage = self.map:GetPage()
    self:Sync()
    return true
end

function D:ApplyInputs()
    if not self:IsEditable() then return false end
    local x, y = tonumber(self.xBox:GetText()), tonumber(self.yBox:GetText())
    if not self:SetNode(self.selected, x, y) then
        message(tr(
            "Ungültige Werte. X 0.06–0.94, Y 0.16–0.84, Dezimalpunkt.",
            "Invalid values. X 0.06–0.94, Y 0.16–0.84, decimal point."))
        return false
    end
    return true
end

function D:ExportText()
    if not self:IsEditable() or not self.target then return nil end
    local page = self.map:GetPage()
    local lines = {
        "-- " .. self.target.label .. ": " .. self.target.file,
        "-- Replace the pages table below. x/y are fractions from the top-left.",
        "-- x = 0.06..0.94, y = 0.16..0.84. Page " .. page .. ":",
        "nodes=" .. fmtNodes(self.pages[page].nodes),
        "",
        "local pages = {",
    }
    for _, entry in ipairs(self.pages) do
        lines[#lines + 1] = "    {texture=" .. string.format("%q", entry.texture) .. ", nodes=" .. fmtNodes(entry.nodes) .. "},"
    end
    lines[#lines + 1] = "}"
    return table.concat(lines, "\n")
end

function D:ShowExport()
    local text = self:ExportText()
    if not text then return false end
    if not self.exportFrame then
        local frame = window("ArcadiaNexus_MapLayoutExport", 640, 460)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        self.exportFrame = frame
        self.exportHelp = label(frame, "", 14, -8, 560, 32)
        button(frame, "X", 28, 596, -8, function() frame:Hide() end)
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -48)
        scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 14)
        local edit = CreateFrame("EditBox", nil, scroll)
        self.exportEdit = edit
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject("GameFontHighlightSmall")
        edit:SetWidth(560)
        edit:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
        edit:SetScript("OnTextChanged", function(box)
            local _, count = box:GetText():gsub("\n", "")
            box:SetHeight(math.max(360, (count + 1) * 14 + 20))
        end)
        frame:SetScript("OnHide", function() edit:ClearFocus() end)
        scroll:SetScrollChild(edit)
    end
    self.exportHelp:SetText(tr(
        "Strg+A, Strg+C. local pages = { ... } in der genannten CampaignMap.lua ersetzen.",
        "Ctrl+A, Ctrl+C. Replace local pages = { ... } in the named CampaignMap.lua."))
    self.exportFrame:Show()
    self.exportEdit:SetText(text)
    self.exportEdit:SetFocus()
    self.exportEdit:HighlightText()
    return true
end

function D:Reset()
    if not self:IsEditable() or not self.baseline then return false end
    self.drag = nil
    for i, nodes in ipairs(self.baseline) do
        for j = 1, 10 do
            self.pages[i].nodes[j][1] = nodes[j][1]
            self.pages[i].nodes[j][2] = nodes[j][2]
        end
    end
    self.map:Refresh()
    self:Sync()
    return true
end

function D:AttachHandles()
    if self.handles then return end
    self.handles = {}
    for i, tile in ipairs(self.map._tiles) do
        local handle = CreateFrame("Frame", nil, tile)
        handle:SetAllPoints(tile)
        handle:EnableMouse(true)
        handle:SetFrameLevel((tile:GetFrameLevel() or 1) + 20)
        local tint = handle:CreateTexture(nil, "BACKGROUND")
        tint:SetPoint("TOPLEFT", handle, "TOPLEFT", 4, -4)
        tint:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", -4, 4)
        handle._tint = tint
        local border = handle:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints(handle)
        handle._border = border
        local hole = handle:CreateTexture(nil, "OVERLAY")
        hole:SetPoint("TOPLEFT", handle, "TOPLEFT", 2, -2)
        hole:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", -2, 2)
        hole:SetColorTexture(0, 0, 0, 0)
        handle:SetScript("OnMouseDown", function(_, btn)
            if btn == "LeftButton" then D:BeginDrag(i) end
        end)
        handle:SetScript("OnMouseUp", function()
            D:Tick(true)
            D.drag = nil
        end)
        self.handles[i] = handle
    end
end

function D:EnsureMap(renderer, pages)
    if self.map and self.mapParent == renderer._canvas then
        self.pages = pages
        return
    end
    if self.map and self.map.Hide then self.map:Hide() end
    self.handles = nil
    self.mapParent = renderer._canvas
    self.pages = pages
    self.map = A.UI.CreateCampaignMap({
        parent = renderer._canvas,
        getPage = function(page) return self.pages[page] end,
        getView = function()
            return {
                levelCount = #self.pages * 10,
                currentLevel = 0,
                titleFormat = "Layout %d-%d",
                subtitle = self.target and self.target.file or "",
                getLevel = function() return { unlocked = true } end,
            }
        end,
        onSelect = function() end,
        onCancel = function() D:Disable() end,
    })
    self:AttachHandles()
end

function D:Build()
    if self.panel then return end
    local frame = window("ArcadiaNexus_MapLayoutEditor", 320, 336)
    self.panel = frame
    label(frame, tr("Kampagnenkarte — Layout", "Campaign map — layout"), 14, -8, 290)
    label(frame, tr(
        "Knoten ziehen. X/Y mit Dezimalpunkt. Export kopieren.",
        "Drag a node. X/Y uses a decimal point. Copy the export."), 14, -26, 290, 32)
    self.pageLabel = label(frame, "", 108, -64, 90)
    button(frame, "<", 36, 14, -66, function() self:SetPage(self.map:GetPage() - 1) end)
    button(frame, ">", 36, 250, -66, function() self:SetPage(self.map:GetPage() + 1) end)
    self.nodeLabel = label(frame, "", 14, -96, 200)
    for i = 1, 10 do
        local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
        button(frame, tostring(i), 52, 14 + col * 58, -124 - row * 26, function() self:Select(i) end)
    end
    label(frame, "X", 14, -186, 120)
    label(frame, "Y", 160, -186, 120)
    local function box(x)
        local edit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        edit:SetSize(120, 22)
        edit:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -208)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(12)
        edit:SetScript("OnEnterPressed", function(widget) self:ApplyInputs(); widget:ClearFocus() end)
        edit:SetScript("OnEscapePressed", function(widget) widget:ClearFocus(); self:Sync() end)
        return edit
    end
    self.xBox = box(18)
    self.yBox = box(164)
    button(frame, tr("Übernehmen", "Apply"), 140, 14, -242, function() self:ApplyInputs() end)
    button(frame, "Export", 140, 164, -242, function() self:ShowExport() end)
    button(frame, tr("Zurücksetzen", "Reset"), 140, 14, -272, function() self:Reset() end)
    button(frame, tr("Schließen", "Close"), 140, 164, -272, function() self:Disable() end)
    frame:SetScript("OnHide", function() self:Disable() end)
    self.loop = A.GameLoop.Create("ArcadiaNexus_MapLayoutLoop", UIParent)
end

function D:Resolve()
    if not allowed() then return nil, "dev" end
    local state = _G.NexusTabState
    local id = state and state.activeCategory
    local target = TARGETS[id]
    local registry = A.GameRegistry
    if not target or not registry then return nil, "game" end
    local container = registry.GetContainer(id)
    if not container or not container.IsShown or not container:IsShown() then return nil, "game" end
    local engine = registry.GetEngine(id)
    if not engine or engine.state ~= "IDLE" then return nil, "busy" end
    local renderer = registry.GetRenderer(id)
    if not renderer or not renderer._canvas then return nil, "game" end
    local pages = target.pages()
    if not validPages(pages) then return nil, "game" end
    return target, id, renderer, pages
end

function D:Enable()
    if self.active then return true end
    local target, id, renderer, pages = self:Resolve()
    if not target then
        if id == "dev" then
            message(tr("DevMode muss aktiviert sein.", "Enable DevMode first."))
        elseif id == "busy" then
            message(tr("Beende zuerst die aktuelle Runde.", "Finish or exit the current round first."))
        else
            message(tr(
                "Öffne zuerst Azeroth Jewels, Shadows Conquest oder BlockBreaker im Spiele-Tab.",
                "Open Azeroth Jewels, Shadows Conquest or BlockBreaker in the games tab first."))
        end
        return false
    end
    self.baselines = self.baselines or {}
    self.baselines[id] = self.baselines[id] or copyNodes(pages)
    self.target, self.gameId, self.renderer = target, id, renderer
    self.baseline, self.pages = self.baselines[id], pages
    self.selected = self.selected or 1
    self:Build()
    self:EnsureMap(renderer, pages)
    local keep = self.map:GetPage()
    self.active = true
    self:Veil()
    self.map:Show(1)
    if keep > 1 then self.map:SetPage(keep) end
    self.seenPage = self.map:GetPage()
    self:Sync()
    self.panel:Show()
    self.loop:Start(function() self:Tick() end)
    return true
end

function D:Disable()
    if not self.active then return end
    self.active = false
    self.drag = nil
    if self.loop then self.loop:Stop() end
    if self.xBox then self.xBox:ClearFocus() end
    if self.yBox then self.yBox:ClearFocus() end
    if self.exportFrame then self.exportFrame:Hide() end
    if self.map then self.map:Hide() end
    if self.panel then
        self.panel:StopMovingOrSizing()
        self.panel:Hide()
    end
    local renderer = self.renderer
    local veiled = self._veiled
    self.renderer = nil
    if renderer and renderer.EnterIdleState then
        pcall(renderer.EnterIdleState, renderer)
    end
    self._veiled = veiled
    self:RestoreVeil(renderer)
end

function D:Tick(released)
    if not self.active then return end
    if not self:ContextOk() then self:Disable(); return end
    self:Veil()
    local page = self.map:GetPage()
    if page ~= self.seenPage then
        self.drag = nil
        self.seenPage = page
        self:Sync()
        return
    end
    if not self.drag then return end
    if not released and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        self.drag = nil
        self:Sync()
        return
    end
    self:MoveSelectedToCursor()
    if released then self.drag = nil end
end

function D:Toggle()
    if self.active then self:Disable(); return true end
    return self:Enable()
end

SlashCmdList = SlashCmdList or {}
SLASH_ARCADIAMAPLAYOUT1 = "/anmap"
SlashCmdList.ARCADIAMAPLAYOUT = function() D:Toggle() end

if A.RegisterDevTool then
    A.RegisterDevTool({
        id = "campaign_map_layout",
        label = "Kampagnenkarte: Layout",
        order = 81,
        hint = "/anmap",
        isAvailable = function() return allowed() end,
        Toggle = function() D:Toggle() end,
    })
end
