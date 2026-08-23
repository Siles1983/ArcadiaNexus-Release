--[[
    ArcadiaNexus – ToastManager
    UI/ToastManager.lua

    Achievement-Toasts: bis zu 3 gleichzeitig, Stapel wächst vom Anker
    nach unten (obere Bildschirmhälfte) oder nach oben (untere Hälfte).
    Klick öffnet den Erfolge-Tab auf der passenden Gruppe.
]]

local TM = {}
ArcadiaNexus.ToastManager = TM

TM._queue     = {}
TM._active    = {}
TM._pool      = {}
TM._pumping   = false

local TOAST_W   = 300
local TOAST_H   = 101
local STACK_GAP = 4
local MAX_VISIBLE = 3
local FADE_IN   = 0.2
local HOLD      = 4.05
local FADE_OUT  = 1.5
local PUSH_DUR  = 0.28

-- ============================================================
-- ATLAS HELPER
-- ============================================================
local function SetAtlasSafe(tex, atlasName)
    local info = C_Texture.GetAtlasInfo(atlasName)
    if info and info.file then
        tex:SetTexture(info.file)
        tex:SetTexCoord(info.leftTexCoord, info.rightTexCoord,
                        info.topTexCoord,  info.bottomTexCoord)
        if info.width  and info.width  > 0 then tex:SetWidth(info.width)   end
        if info.height and info.height > 0 then tex:SetHeight(info.height) end
        return true
    end
    return false
end

-- ============================================================
-- FADE / ANIMATION HELPERS
-- ============================================================
local function FadeFrame(frame, fromAlpha, toAlpha, duration, onDone)
    if type(duration) ~= "number" or duration <= 0 then duration = 0.01 end
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        if type(dt) ~= "number" then dt = 0 end
        elapsed = elapsed + dt
        local t = math.min(elapsed / duration, 1)
        self:SetAlpha(fromAlpha + (toAlpha - fromAlpha) * t)
        if t >= 1 then
            self:SetScript("OnUpdate", nil)
            if onDone then onDone() end
        end
    end)
end

local function FadeTexture(tex, fromAlpha, toAlpha, duration, onDone)
    local elapsed = 0
    C_Timer.NewTicker(0.016, function()
        elapsed = elapsed + 0.016
        local t = math.min(elapsed / duration, 1)
        tex:SetAlpha(fromAlpha + (toAlpha - fromAlpha) * t)
        if t >= 1 then
            if onDone then onDone() end
        end
    end, math.ceil(duration / 0.016) + 1)
end

local function AnimateShine(shineTex, baseX, baseY)
    if not shineTex then return end
    shineTex:SetAlpha(0)
    shineTex:Show()
    local elapsed = 0
    local ticker = C_Timer.NewTicker(0.016, function()
        elapsed = elapsed + 0.016
        if elapsed <= 0.2 then
            shineTex:SetAlpha(elapsed / 0.2)
        elseif elapsed <= 0.85 then
            local t = (elapsed - 0.2) / 0.65
            shineTex:ClearAllPoints()
            shineTex:SetPoint("BOTTOMLEFT", shineTex:GetParent(), "BOTTOMLEFT",
                baseX + t * 240, baseY)
        elseif elapsed <= 1.35 then
            local t = (elapsed - 0.85) / 0.5
            shineTex:SetAlpha(1 - t)
        else
            shineTex:SetAlpha(0)
            shineTex:Hide()
            shineTex:ClearAllPoints()
            shineTex:SetPoint("BOTTOMLEFT", shineTex:GetParent(), "BOTTOMLEFT", baseX, baseY)
        end
    end)
    return ticker
end

local function GrowDown()
    local db = ArcadiaNexusDB and ArcadiaNexusDB.toastAnchor
    local ay = (db and db.y) or -200
    local uh = (UIParent and UIParent:GetHeight()) or 768
    return ay > -(uh / 2)
end

local function AnchorXY()
    local db = ArcadiaNexusDB and ArcadiaNexusDB.toastAnchor
    return (db and db.x) or 0, (db and db.y) or -200
end

local function SlotPoint(slot)
    local ax, ay = AnchorXY()
    local offset = slot * (TOAST_H + STACK_GAP)
    if GrowDown() then
        return ax, ay - offset
    end
    return ax, ay + offset
end

local function SetToastPoint(frame, slot)
    local ax, ay = SlotPoint(slot)
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", ax, ay)
    frame._curY = ay
    frame._slot = slot
end

local function CancelMove(frame)
    if frame and frame._moveTicker then
        frame._moveTicker:Cancel()
        frame._moveTicker = nil
    end
end

local function AnimateToSlot(frame, slot, duration)
    if not frame then return end
    CancelMove(frame)
    local ax, toY = SlotPoint(slot)
    local fromY = frame._curY
    if fromY == nil then
        local _, _, _, _, py = frame:GetPoint(1)
        fromY = py or toY
    end
    frame._slot = slot
    duration = duration or PUSH_DUR
    if duration <= 0 or math.abs((fromY or toY) - toY) < 0.5 then
        SetToastPoint(frame, slot)
        return
    end
    local elapsed = 0
    local ticker
    ticker = C_Timer.NewTicker(0.016, function()
        elapsed = elapsed + 0.016
        local t = math.min(elapsed / duration, 1)
        local e = 1 - (1 - t) * (1 - t)
        local ny = fromY + (toY - fromY) * e
        frame:ClearAllPoints()
        frame:SetPoint("TOP", UIParent, "TOP", ax, ny)
        frame._curY = ny
        if t >= 1 then
            if ticker then ticker:Cancel() end
            frame._moveTicker = nil
            SetToastPoint(frame, slot)
        end
    end, math.ceil(duration / 0.016) + 1)
    frame._moveTicker = ticker
end

local function PositionToast(frame, slot)
    SetToastPoint(frame, slot)
end

-- ============================================================
-- FRAME POOL
-- ============================================================
local _toastSeq = 0

local function RecycleFrame(f)
    if not f then return end
    CancelMove(f)
    f:SetScript("OnUpdate", nil)
    f:Hide()
    f:SetAlpha(0)
    f._item = nil
    f._slot = nil
    f._curY = nil
    f._busy = false
    f._gen  = (f._gen or 0) + 1
    table.insert(TM._pool, f)
end

local function CreateToastFrame()
    _toastSeq = _toastSeq + 1
    local f = CreateFrame("Button", "NexusToastFrame" .. _toastSeq, UIParent)
    f:SetSize(TOAST_W, TOAST_H)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:SetAlpha(0)
    f:Hide()
    f._gen = 0

    local bg = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetPoint("CENTER", f, "CENTER", 0, 0)
    if not SetAtlasSafe(bg, "ui-achievement-alert-background") then
        bg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Toast-Glow")
        bg:SetAllPoints(f)
    end
    f._bgTex = bg

    local glow = f:CreateTexture(nil, "OVERLAY", nil, 0)
    glow:SetPoint("CENTER", f, "CENTER", 0, 0)
    glow:SetBlendMode("ADD")
    glow:Hide()
    SetAtlasSafe(glow, "ui-achievement-alert-glow-glow")
    f._glowTex = glow

    local shine = f:CreateTexture(nil, "OVERLAY", nil, 1)
    shine:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 8)
    shine:SetBlendMode("ADD")
    shine:Hide()
    SetAtlasSafe(shine, "ui-achievement-alert-glow-shine")
    f._shineTex = shine

    local iconHolder = CreateFrame("Frame", nil, f)
    iconHolder:SetSize(78, 75)
    iconHolder:SetPoint("TOPLEFT", f, "TOPLEFT", -4, -15)

    local iconTex = iconHolder:CreateTexture(nil, "ARTWORK", nil, 0)
    iconTex:SetSize(52, 52)
    iconTex:SetPoint("CENTER", iconHolder, "CENTER", 0, 0)
    f._iconTex = iconTex

    local iconOverlay = iconHolder:CreateTexture(nil, "OVERLAY", nil, 1)
    iconOverlay:SetPoint("CENTER", iconHolder, "CENTER", -1, 1)
    if not SetAtlasSafe(iconOverlay, "ui-achievement-iconframe") then
        iconOverlay:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
        iconOverlay:SetTexCoord(0, 0.5625, 0, 0.5625)
        iconOverlay:SetSize(60, 60)
    end

    local unlockedFS = f:CreateFontString(nil, "BACKGROUND", "GameFontBlackTiny")
    unlockedFS:SetSize(200, 12)
    unlockedFS:SetPoint("TOP", f, "TOP", 7, -23)
    unlockedFS:SetJustifyH("CENTER")
    f._unlockedFS = unlockedFS

    local nameFS = f:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
    nameFS:SetSize(155, 36)
    nameFS:SetPoint("TOP", unlockedFS, "BOTTOM", 0, 0)
    nameFS:SetJustifyH("CENTER")
    nameFS:SetJustifyV("MIDDLE")
    nameFS:SetMaxLines(2)
    f._nameFS = nameFS

    local shieldHolder = CreateFrame("Frame", nil, f)
    shieldHolder:SetSize(64, 64)
    shieldHolder:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -15)
    f._shieldHolder = shieldHolder

    local shieldIcon = shieldHolder:CreateTexture(nil, "BACKGROUND", nil, 0)
    shieldIcon:SetPoint("TOPRIGHT", shieldHolder, "TOPRIGHT", 1, -6)
    if not SetAtlasSafe(shieldIcon, "ui-achievement-shield-2") then
        shieldIcon:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields")
        shieldIcon:SetTexCoord(0, 0.5, 0, 0.5)
        shieldIcon:SetSize(48, 48)
    end
    f._shieldIcon = shieldIcon

    local shieldPts = shieldHolder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    shieldPts:SetPoint("CENTER", shieldHolder, "CENTER", 2, -2)
    shieldPts:SetJustifyH("CENTER")
    f._shieldPtsFS = shieldPts

    f:SetScript("OnClick", function(self)
        local item = self._item
        if not item or item.isGold or (item.data and item.data._preview) then
            return
        end
        local ach = item.data
        if ach and ArcadiaNexus.UI and ArcadiaNexus.UI.OpenAchievementFromToast then
            pcall(function() ArcadiaNexus.UI.OpenAchievementFromToast(ach) end)
        end
    end)

    return f
end

local function AcquireFrame()
    local f = table.remove(TM._pool)
    if not f then
        f = CreateToastFrame()
    end
    f._busy = true
    return f
end

-- ============================================================
-- FILL TOAST CONTENT
-- ============================================================
local function ApplyItem(f, item)
    local L      = ArcadiaNexus.GetLocaleTable("UI")
    local locale = ArcadiaNexus.ActiveLocale or "enUS"

    if item.isGold then
        if f._bgTex then f._bgTex:SetVertexColor(0.95, 0.82, 0.10) end
        f._iconTex:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        f._shieldHolder:Hide()
        f._unlockedFS:SetText(L["toast_gold_earned"] or "Tavern Gold erhalten!")
        f._nameFS:SetText("|cffffd700+" .. tostring(item.amount) .. " Gold|r")
        return
    end

    local ach = item.data
    if f._bgTex then f._bgTex:SetVertexColor(1, 1, 1) end
    f._shieldHolder:Show()

    local AI = ArcadiaNexus.AchievementIcons
    if AI and AI.ApplyToTexture then
        AI:ApplyToTexture(f._iconTex, ach.icon)
    else
        f._iconTex:SetTexture(ach.icon or "Interface\\Icons\\Achievement_General_StayClassy")
    end

    local isChallenge = ach._type == "challenge"
    f._unlockedFS:SetText(isChallenge
        and (L["toast_challenge_complete"] or "Challenge abgeschlossen!")
        or  (ACHIEVEMENT_UNLOCKED or L["toast_achievement_earned"] or "Erfolg errungen!"))

    local title = (locale == "deDE" and ach.title_de) or ach.title_en or ach.title_de or "?"
    f._nameFS:SetText(title)

    local xp = (type(ach.tierXP) == "number" and ach.tierXP)
            or (type(ach.xp)    == "number" and ach.xp)
            or 0
    if xp > 0 then
        f._shieldPtsFS:SetText(tostring(xp))
        f._shieldPtsFS:SetVertexColor(1, 1, 1)
        f._shieldIcon:Show()
    else
        f._shieldPtsFS:SetText("")
        f._shieldIcon:Hide()
    end
end

local function RemoveActive(f)
    for i, rec in ipairs(TM._active) do
        if rec.frame == f then
            table.remove(TM._active, i)
            break
        end
    end
    RecycleFrame(f)
    TM:_Pump()
end

local function PlayToast(f)
    local gen = f._gen or 0
    f:SetAlpha(0)
    f:Show()
    FadeFrame(f, 0, 1, FADE_IN, function()
        if f._gen ~= gen or not f._busy then return end
        local glow = f._glowTex
        if glow then
            glow:SetAlpha(0); glow:Show()
            FadeTexture(glow, 0, 1, 0.2, function()
                FadeTexture(glow, 1, 0, 0.5, function() glow:Hide() end)
            end)
        end
        AnimateShine(f._shineTex, 0, 8)

        if SOUNDKIT and SOUNDKIT.UI_ACHIEVEMENT_TOAST_SPARK then
            pcall(function() C_Sound.PlaySound(SOUNDKIT.UI_ACHIEVEMENT_TOAST_SPARK) end)
        end

        C_Timer.After(HOLD, function()
            if f._gen ~= gen or not f._busy then return end
            FadeFrame(f, f:GetAlpha(), 0, FADE_OUT, function()
                if f._gen ~= gen or not f._busy then return end
                RemoveActive(f)
            end)
        end)
    end)
end

-- ============================================================
-- QUEUE
-- ============================================================
function TM:_Pump()
    if self._pumping then return end
    if #self._queue == 0 or #self._active >= MAX_VISIBLE then return end
    self._pumping = true
    local gen = (self._pumpGen or 0)

    for _, rec in ipairs(self._active) do
        rec.slot = (rec.slot or 0) + 1
        AnimateToSlot(rec.frame, rec.slot, PUSH_DUR)
    end

    local item = table.remove(self._queue, 1)
    local f = AcquireFrame()
    f._item = item
    ApplyItem(f, item)
    SetToastPoint(f, 0)
    table.insert(self._active, 1, { frame = f, item = item, slot = 0 })
    PlayToast(f)

    C_Timer.After(PUSH_DUR, function()
        if TM._pumpGen ~= gen then return end
        TM._pumping = false
        TM:_Pump()
    end)
end

function TM:Init()
    if not ArcadiaNexusDB.toastAnchor then
        ArcadiaNexusDB.toastAnchor = { x = 0, y = -200 }
    end

    ArcadiaNexus.Engine:On("ACHIEVEMENT_UNLOCKED", function(ach)
        local ok, err = pcall(function() TM:Show(ach) end)
        if not ok and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444ArcadiaNexus|r Toast error: " .. tostring(err))
        end
    end)

    ArcadiaNexus.Engine:On("CHALLENGE_COMPLETE", function(ch)
        pcall(function()
            TM:Show({
                icon    = "Interface\\Icons\\Achievement_General_StayClassy",
                title_de = ch.title_de or ch.title_en or "Challenge",
                title_en = ch.title_en or "Challenge",
                _type    = "challenge",
                xp       = ch.reward or 0,
            })
        end)
    end)
end

function TM:Show(ach)
    if not ach then return end
    table.insert(self._queue, { data = ach, isGold = false })
    self:_Pump()
end

function TM:ShowGold(amount, reason)
    table.insert(self._queue, { isGold = true, amount = amount, reason = reason })
    self:_Pump()
end

function TM:ClearAll()
    self._pumpGen = (self._pumpGen or 0) + 1
    self._pumping = false
    wipe(self._queue)
    local snapshot = {}
    for i, rec in ipairs(self._active) do
        snapshot[i] = rec.frame
    end
    wipe(self._active)
    for _, f in ipairs(snapshot) do
        RecycleFrame(f)
    end
end

--- Vorschau: 3 Toasts in Wachstumsrichtung vom aktuellen Anker.
function TM:PreviewStack()
    self:ClearAll()
    for i = 1, MAX_VISIBLE do
        self:Show({
            icon     = "Interface\\Icons\\Achievement_General_StayClassy",
            title_de = "Vorschau-Erfolg " .. i,
            title_en = "Preview Achievement " .. i,
            desc_de  = "Wachstumsrichtung vom Anker.",
            desc_en  = "Stack direction from the anchor.",
            xp       = 25,
            _preview = true,
        })
    end
end

function TM:UpdateAnchor()
    local db = ArcadiaNexusDB and ArcadiaNexusDB.toastAnchor
    if not db then return end
    for _, rec in ipairs(self._active) do
        if rec.frame then
            AnimateToSlot(rec.frame, rec.slot or 0, 0)
        end
    end
end
