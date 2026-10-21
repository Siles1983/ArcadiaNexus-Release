--[[
    Shared paginated campaign / level selection. Layout follows Azeroth Jewels.
    API and consumer contract: docs/Hub/CampaignMap.md.
    Owns presentation only; games supply progress and validate selections.
]]
local UI = ArcadiaNexus.UI

local PAGE_SIZE = 10
local COLS = 5
local PANEL_W, PANEL_H = 348, 268
local TILE_W, TILE_H = 54, 62
local GAP_X, GAP_Y = 8, 10
local ROUND_SIZE = 38
local WHITE = "Interface\\Buttons\\WHITE8X8"
local MASK_TEX = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function AttachCircleMask(parent, tex)
    if not tex or not parent or not parent.CreateMaskTexture or not tex.AddMaskTexture then
        return nil
    end
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(MASK_TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
    return mask
end

local function PaintRound(tile, kind)
    local bg, ring, num = tile._bg, tile._ring, tile._number
    if kind == "locked" then
        if bg then bg:SetVertexColor(0.08, 0.08, 0.11, 0.95) end
        if ring then ring:SetVertexColor(0.28, 0.28, 0.33, 1) end
        num:SetTextColor(0.45, 0.45, 0.50)
    elseif kind == "current" then
        if bg then bg:SetVertexColor(0.18, 0.12, 0.03, 0.98) end
        if ring then ring:SetVertexColor(1, 0.82, 0.22, 1) end
        num:SetTextColor(1, 0.92, 0.44)
    elseif kind == "completed" then
        if bg then bg:SetVertexColor(0.08, 0.16, 0.12, 0.95) end
        if ring then ring:SetVertexColor(0.45, 0.72, 0.42, 0.95) end
        num:SetTextColor(0.78, 0.90, 0.72)
    else
        if bg then bg:SetVertexColor(0.08, 0.17, 0.32, 0.94) end
        if ring then ring:SetVertexColor(0.35, 0.65, 1, 0.9) end
        num:SetTextColor(0.83, 0.91, 1)
    end
end

local function PaintStars(tile, unlocked, stars)
    if not tile._starTexs then return end
    stars = math.max(0, math.min(3, math.floor(tonumber(stars) or 0)))
    for i = 1, 3 do
        local star = tile._starTexs[i]
        if unlocked and i <= stars then
            star:SetVertexColor(1.00, 0.82, 0.00, 1)
        elseif unlocked then
            star:SetVertexColor(0.45, 0.45, 0.48, 0.72)
        else
            star:SetVertexColor(0.28, 0.28, 0.33, 0.72)
        end
    end
end

function UI.CreateCampaignMap(config)
    assert(config and config.parent, "CreateCampaignMap: design canvas is required")
    assert(type(config.getView) == "function", "CreateCampaignMap: getView is required")
    assert(type(config.onSelect) == "function", "CreateCampaignMap: onSelect is required")
    local illustrated = type(config.getPage) == "function"
    local panelW, panelH = illustrated and 450 or PANEL_W, illustrated and 450 or PANEL_H
    local tileW, tileH = illustrated and ROUND_SIZE or TILE_W, illustrated and ROUND_SIZE or TILE_H

    local frame = CreateFrame("Frame", nil, config.parent)
    frame:SetAllPoints(config.parent)
    frame:SetFrameLevel(config.parent:GetFrameLevel() + 40)
    frame:Hide()

    local panel = CreateFrame("Frame", nil, frame)
    panel:SetSize(panelW, panelH)
    panel:SetPoint("CENTER", frame, "CENTER", 0, illustrated and 0 or 38)
    panel:EnableMouse(true)
    local gold = UI.CreateGoldGridFrame(frame, panel, {
        w = panelW, h = panelH, pad = 10, fillAlpha = illustrated and 0 or 0.75, levelAdd = 1,
    })
    panel:SetFrameLevel(frame:GetFrameLevel() + 4)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -14)
    title:SetWidth(panelW - 20)
    title:SetTextColor(1, 0.85, 0.35)
    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
    subtitle:SetWidth(panelW - 20)
    subtitle:SetTextColor(0.80, 0.80, 0.70)

    local api = { frame = frame, _tiles = {}, _page = 1, _pages = 1, _illustrated = illustrated }
    local art, lines
    if illustrated then
        art = panel:CreateTexture(nil, "BACKGROUND")
        art:SetAllPoints(panel)
        for _, anchor in ipairs({"TOP", "BOTTOM"}) do
            local shade = panel:CreateTexture(nil, "ARTWORK")
            shade:SetColorTexture(0.02, 0.025, 0.04, 0.88)
            shade:SetSize(panelW, anchor == "TOP" and 48 or 44)
            shade:SetPoint(anchor, panel, anchor)
        end
        lines = {}
        for i = 1, PAGE_SIZE - 1 do
            local line = panel:CreateLine(nil, "ARTWORK")
            line:SetThickness(2)
            lines[i] = line
        end
        api._art, api._lines = art, lines
    end
    local function HideTooltip()
        if UI.HideFrameTooltip then UI.HideFrameTooltip() end
    end
    frame:SetScript("OnHide", function()
        HideTooltip()
        if api._overlayOpen then
            api._overlayOpen = nil
            local GI = ArcadiaNexus.GameInput
            if GI and GI.OnUiOverlayClosed then GI.OnUiOverlayClosed(api._overlayButtons) end
            api._overlayButtons = nil
        end
    end)

    local padX = math.floor((PANEL_W - COLS * TILE_W - (COLS - 1) * GAP_X) / 2)
    for i = 1, PAGE_SIZE do
        local tile = CreateFrame("Button", nil, panel, illustrated and nil or "BackdropTemplate")
        tile:SetSize(tileW, tileH)
        tile:SetPoint("TOPLEFT", panel, "TOPLEFT",
            padX + ((i - 1) % COLS) * (TILE_W + GAP_X),
            -58 - math.floor((i - 1) / COLS) * (TILE_H + GAP_Y))
        if illustrated then
            local ring = tile:CreateTexture(nil, "BACKGROUND")
            ring:SetTexture(WHITE)
            ring:SetPoint("TOPLEFT", tile, "TOPLEFT", -1, 1)
            ring:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", 1, -1)
            tile._ring, tile._ringMask = ring, AttachCircleMask(tile, ring)
            local bg = tile:CreateTexture(nil, "ARTWORK")
            bg:SetTexture(WHITE)
            bg:SetPoint("TOPLEFT", tile, "TOPLEFT", 2, -2)
            bg:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -2, 2)
            tile._bg, tile._bgMask = bg, AttachCircleMask(tile, bg)
            local starHolder = CreateFrame("Frame", nil, panel)
            starHolder:SetSize(42, 14)
            starHolder:SetPoint("TOP", tile, "BOTTOM", 0, -1)
            starHolder:SetFrameLevel((tile:GetFrameLevel() or 1) + 4)
            starHolder:Hide()
            tile._starTexs = {}
            for starIndex = 1, 3 do
                local star = starHolder:CreateTexture(nil, "OVERLAY")
                star:SetAtlas("auctionhouse-icon-favorite", false)
                star:SetSize(12, 12)
                star:SetPoint("CENTER", starHolder, "LEFT", 7 + (starIndex - 1) * 14, 0)
                tile._starTexs[starIndex] = star
            end
            tile._starHolder = starHolder
        else
            tile:SetBackdrop({
                bgFile = WHITE, edgeFile = WHITE,
                edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
        end
        tile:RegisterForClicks("LeftButtonUp")
        tile._number = tile:CreateFontString(nil, "OVERLAY", illustrated and "GameFontNormalSmall" or "GameFontNormal")
        tile._text = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tile._subtext = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        local labelW = illustrated and 52 or (tileW - 4)
        tile._number:SetWidth(tileW - 4)
        tile._text:SetWidth(labelW)
        tile._subtext:SetWidth(labelW)
        for _, fs in ipairs({ tile._number, tile._text, tile._subtext }) do
            fs:SetJustifyH("CENTER")
            fs:SetWordWrap(false)
        end
        tile:SetScript("OnClick", function(btn)
            if frame:IsShown() and btn._level and not btn._locked then
                config.onSelect(btn._level)
            end
        end)
        tile:SetScript("OnEnter", function(btn)
            if btn._tooltipText and UI.ShowFrameTooltip then
                UI.ShowFrameTooltip(btn, btn._tooltipTitle, btn._tooltipText)
            end
        end)
        tile:SetScript("OnLeave", HideTooltip)
        api._tiles[i] = tile
    end

    local prev = UI.CreateArcadiaButton(panel, "<", 36, 28)
    prev:SetPoint("BOTTOM", panel, "BOTTOM", -90, 12)
    prev:SetScript("OnClick", function() api:SetPage(api._page - 1) end)
    local nextPage = UI.CreateArcadiaButton(panel, ">", 36, 28)
    nextPage:SetPoint("BOTTOM", panel, "BOTTOM", 90, 12)
    nextPage:SetScript("OnClick", function() api:SetPage(api._page + 1) end)
    local pageText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pageText:SetPoint("BOTTOM", panel, "BOTTOM", 0, 18)
    pageText:SetTextColor(0.80, 0.80, 0.70)
    local action = UI.CreateArcadiaButton(illustrated and panel or frame, "", 125, 28)
    action:SetPoint(illustrated and "BOTTOM" or "TOP", panel, "BOTTOM", 0, illustrated and 10 or -14)
    if illustrated then
        prev:ClearAllPoints(); prev:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 9)
        nextPage:ClearAllPoints(); nextPage:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 110, 9)
        pageText:ClearAllPoints(); pageText:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 57, 15)
        action:ClearAllPoints(); action:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 9)
    end
    action:Hide()
    action:SetScript("OnClick", function()
        if frame:IsShown() and action:IsShown() and config.onAction then config.onAction() end
    end)
    api._prev, api._next, api._action = prev, nextPage, action
    local fallback = {{.10,.82},{.22,.74},{.35,.67},{.48,.59},{.61,.54},
        {.53,.42},{.66,.36},{.79,.32},{.76,.20},{.89,.18}}
    local function Coord(value, lo, hi, default)
        return type(value) == "number" and value == value and value >= lo and value <= hi and value or default
    end

    function api:Refresh(focusLevel)
        HideTooltip()
        local view = config.getView() or {}
        local count = math.max(1, math.floor(tonumber(view.levelCount) or 1))
        self._pages = math.ceil(count / PAGE_SIZE)
        if focusLevel then
            local focus = math.max(1, math.min(count, math.floor(tonumber(focusLevel) or 1)))
            self._page = math.ceil(focus / PAGE_SIZE)
        end
        self._page = math.max(1, math.min(self._page, self._pages))
        local first = (self._page - 1) * PAGE_SIZE + 1
        local last = view.padLastPage and self._page * PAGE_SIZE or math.min(count, self._page * PAGE_SIZE)
        title:SetText(string.format(view.titleFormat or "Level %d–%d", first, last))
        subtitle:SetText(view.subtitle or "")
        pageText:SetText(string.format("%d / %d", self._page, self._pages))
        prev:SetEnabled(self._page > 1)
        nextPage:SetEnabled(self._page < self._pages)
        local nodes
        if illustrated then
            local page = config.getPage(self._page)
            if type(page) ~= "table" then page = {} end
            local texture = type(page.texture) == "string" and page.texture ~= "" and page.texture or nil
            art:SetTexture(texture); art:SetShown(texture ~= nil)
            nodes = {}
            for i, tile in ipairs(self._tiles) do
                local p = type(page.nodes) == "table" and page.nodes[i] or nil
                p = type(p) == "table" and p or {}
                local x = Coord(p[1], .06, .94, fallback[i][1])
                local y = Coord(p[2], .16, .84, fallback[i][2])
                nodes[i] = {x * panelW, -y * panelH}
                tile:ClearAllPoints()
                tile:SetPoint("CENTER", panel, "TOPLEFT", nodes[i][1], nodes[i][2])
            end
        end
        action:SetLabel(view.actionLabel or "")
        action:SetShown(view.actionLabel ~= nil and view.actionLabel ~= "" and config.onAction ~= nil)

        local current = math.max(1, math.min(count, tonumber(view.currentLevel) or 1))
        for i, tile in ipairs(self._tiles) do
            local level = first + i - 1
            -- Reset every reusable tile, including hidden entries on the last page.
            tile._level, tile._tooltipTitle, tile._tooltipText = nil, nil, nil
            tile._locked = true
            tile._number:SetText("")
            tile._text:SetText("")
            tile._subtext:SetText("")
            tile:Disable()
            tile:SetShown(level <= last)
            if tile._starHolder then tile._starHolder:Hide() end
            if level <= last then
                local data = level <= count and view.getLevel and view.getLevel(level) or {}
                data = data or {}
                local unlocked = level <= count and data.unlocked == true
                local showStars = illustrated and type(data.stars) == "number"
                tile._level, tile._locked = level, not unlocked
                tile:SetEnabled(unlocked)
                tile._number:SetText(tostring(level))
                tile._tooltipTitle, tile._tooltipText = data.tooltipTitle, data.tooltipText
                tile._number:ClearAllPoints()
                tile._text:ClearAllPoints()
                tile._subtext:ClearAllPoints()
                if illustrated then
                    tile._number:SetPoint("CENTER", tile, "CENTER", 0, 0)
                    if showStars then
                        tile._text:SetText("")
                        tile._subtext:SetText("")
                        tile._starHolder:Show()
                        PaintStars(tile, unlocked, data.stars)
                    else
                        tile._text:SetText(unlocked and (data.text or "—") or (data.lockedText or view.lockedText or "—"))
                        tile._subtext:SetText(unlocked and (data.subtext or "") or "")
                        tile._text:SetPoint("TOP", tile, "BOTTOM", 0, -2)
                        tile._subtext:SetPoint("TOP", tile._text, "BOTTOM", 0, 0)
                    end
                    local kind = "open"
                    if not unlocked then
                        kind = data.completed == true and "completed" or "locked"
                    elseif level == current then
                        kind = "current"
                    end
                    PaintRound(tile, kind)
                else
                    tile._text:SetText(unlocked and (data.text or "—") or (data.lockedText or view.lockedText or "—"))
                    tile._subtext:SetText(unlocked and (data.subtext or "") or "")
                    local twoLines = unlocked and data.subtext and data.subtext ~= ""
                    tile._number:SetPoint("CENTER", tile, "CENTER", 0, twoLines and 17 or 8)
                    tile._text:SetPoint("CENTER", tile, "CENTER", 0, twoLines and -2 or -12)
                    tile._subtext:SetPoint("CENTER", tile, "CENTER", 0, -17)
                    if not unlocked then
                        tile:SetBackdropColor(0.08, 0.08, 0.10, 0.85)
                        tile:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
                        tile._number:SetTextColor(0.45, 0.45, 0.48)
                    elseif level == current then
                        tile:SetBackdropColor(0.18, 0.14, 0.06, 0.95)
                        tile:SetBackdropBorderColor(1, 0.84, 0.2, 1)
                        tile._number:SetTextColor(1, 0.90, 0.40)
                    else
                        tile:SetBackdropColor(0.10, 0.12, 0.16, 0.90)
                        tile:SetBackdropBorderColor(0.55, 0.50, 0.32, 1)
                        tile._number:SetTextColor(0.90, 0.88, 0.80)
                    end
                end
                if unlocked then
                    tile._text:SetTextColor(1, 0.82, 0.2)
                    tile._subtext:SetTextColor(0.80, 0.80, 0.70)
                else
                    tile._text:SetTextColor(0.40, 0.40, 0.42)
                    tile._subtext:SetTextColor(0.40, 0.40, 0.42)
                end
            end
        end
        if illustrated then
            for i, line in ipairs(lines) do
                line:SetStartPoint("TOPLEFT", panel, nodes[i][1], nodes[i][2])
                line:SetEndPoint("TOPLEFT", panel, nodes[i+1][1], nodes[i+1][2])
                local open = not self._tiles[i+1]._locked
                line:SetColorTexture(open and 0.9 or 0.25, open and 0.7 or 0.25, open and 0.3 or 0.28, 0.8)
                line:SetShown(first + i <= last)
            end
        end
    end

    function api:Show(focusLevel)
        self:Refresh(focusLevel)
        gold:Show()
        frame:Show()
        if illustrated and not self._overlayOpen then
            local GI = ArcadiaNexus.GameInput
            if GI and GI.OnUiOverlay then
                local buttons = {}
                for _, tile in ipairs(self._tiles) do buttons[#buttons+1] = tile end
                buttons[#buttons+1], buttons[#buttons+2] = prev, nextPage
                buttons[#buttons+1] = action
                self._overlayOpen = true
                self._overlayButtons = buttons
                GI.OnUiOverlay(buttons, {onCancel=config.onCancel})
            end
        end
    end
    function api:Hide() frame:Hide(); gold:Hide() end
    function api:IsShown() return frame:IsShown() end
    function api:GetPage() return self._page end
    function api:GetPageCount() return self._pages end
    function api:SetPage(page)
        self._page = math.floor(tonumber(page) or 1)
        self:Refresh()
    end
    return api
end
