--[[
    Shared paginated campaign / level selection. Layout follows Azeroth Jewels.
    API and consumer contract: docs/CampaignMap.md.
    Owns presentation only; games supply progress and validate selections.
]]
local UI = ArcadiaNexus.UI

local PAGE_SIZE = 10
local COLS = 5
local PANEL_W, PANEL_H = 348, 268
local TILE_W, TILE_H = 54, 62
local GAP_X, GAP_Y = 8, 10

function UI.CreateCampaignMap(config)
    assert(config and config.parent, "CreateCampaignMap: design canvas is required")
    assert(type(config.getView) == "function", "CreateCampaignMap: getView is required")
    assert(type(config.onSelect) == "function", "CreateCampaignMap: onSelect is required")

    local frame = CreateFrame("Frame", nil, config.parent)
    frame:SetAllPoints(config.parent)
    frame:SetFrameLevel(config.parent:GetFrameLevel() + 40)
    frame:Hide()

    local panel = CreateFrame("Frame", nil, frame)
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetPoint("CENTER", frame, "CENTER", 0, 38)
    panel:EnableMouse(true)
    local gold = UI.CreateGoldGridFrame(frame, panel, {
        w = PANEL_W, h = PANEL_H, pad = 10, fillAlpha = 0.75, levelAdd = 1,
    })
    panel:SetFrameLevel(frame:GetFrameLevel() + 4)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -14)
    title:SetWidth(PANEL_W - 20)
    title:SetTextColor(1, 0.85, 0.35)
    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
    subtitle:SetWidth(PANEL_W - 20)
    subtitle:SetTextColor(0.80, 0.80, 0.70)

    local api = { frame = frame, _tiles = {}, _page = 1, _pages = 1 }
    local function HideTooltip()
        if UI.HideFrameTooltip then UI.HideFrameTooltip() end
    end
    frame:SetScript("OnHide", HideTooltip)

    local padX = math.floor((PANEL_W - COLS * TILE_W - (COLS - 1) * GAP_X) / 2)
    for i = 1, PAGE_SIZE do
        local tile = CreateFrame("Button", nil, panel, "BackdropTemplate")
        tile:SetSize(TILE_W, TILE_H)
        tile:SetPoint("TOPLEFT", panel, "TOPLEFT",
            padX + ((i - 1) % COLS) * (TILE_W + GAP_X),
            -58 - math.floor((i - 1) / COLS) * (TILE_H + GAP_Y))
        tile:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        tile:RegisterForClicks("LeftButtonUp")
        tile._number = tile:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tile._text = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tile._subtext = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        for _, fs in ipairs({ tile._number, tile._text, tile._subtext }) do
            fs:SetWidth(TILE_W - 4)
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
    local action = UI.CreateArcadiaButton(frame, "", 125, 28)
    action:SetPoint("TOP", panel, "BOTTOM", 0, -14)
    action:Hide()
    action:SetScript("OnClick", function()
        if frame:IsShown() and action:IsShown() and config.onAction then config.onAction() end
    end)
    api._prev, api._next, api._action = prev, nextPage, action

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
            if level <= last then
                local data = level <= count and view.getLevel and view.getLevel(level) or {}
                data = data or {}
                local unlocked = level <= count and data.unlocked == true
                tile._level, tile._locked = level, not unlocked
                tile:SetEnabled(unlocked)
                tile._number:SetText(tostring(level))
                tile._text:SetText(unlocked and (data.text or "—") or (view.lockedText or "—"))
                tile._subtext:SetText(unlocked and (data.subtext or "") or "")
                tile._tooltipTitle, tile._tooltipText = data.tooltipTitle, data.tooltipText
                local twoLines = unlocked and data.subtext and data.subtext ~= ""
                tile._number:ClearAllPoints()
                tile._text:ClearAllPoints()
                tile._subtext:ClearAllPoints()
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
                if unlocked then
                    tile._text:SetTextColor(1, 0.82, 0.2)
                    tile._subtext:SetTextColor(0.80, 0.80, 0.70)
                else
                    tile._text:SetTextColor(0.40, 0.40, 0.42)
                    tile._subtext:SetTextColor(0.40, 0.40, 0.42)
                end
            end
        end
    end

    function api:Show(focusLevel)
        self:Refresh(focusLevel)
        gold:Show()
        frame:Show()
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
