--[[
    NEXUS GAMING HUB
    Modul: HUD
    Verantwortlich für: UpdateBadge, Engine-Event-Listener
                        (XP_UPDATED, ARCADE_LEVEL_UP)

    Abhängigkeiten:
        UI/ArcadiaNexus_UI.lua   (F via ArcadiaNexus.UI.GetF())
        Core/Engine.lua       (ArcadiaNexus.Engine:On)

    Exportiert:
        ArcadiaNexus.UI.UpdateBadge
]]

local function F() return ArcadiaNexus.UI.GetF() end

local _L = nil
local function L(key)
    if not _L then _L = ArcadiaNexus.GetLocaleTable("UI") end
    return _L[key]
end

local function UpdateBadge()
    if not F().badgeFS then return end

    local profile = ArcadiaNexusDB and ArcadiaNexusDB.profile
    local xp, xpReq, level
    if not profile then
        xp = 0; xpReq = 93; level = 1
    else
        xp    = profile.xp         or 0
        xpReq = profile.xpRequired or 93
        level = profile.level      or 1
    end

    if F().badgeBar then
        local XPM = ArcadiaNexus.XPManager
        local maxLevel = XPM and XPM.IsMaxLevel and XPM:IsMaxLevel()
        if maxLevel or xpReq == 0 then
            F().badgeBar:SetValue(1)
            F().badgeFS:SetText("MAX LEVEL")
        else
            local ratio = math.min(1, xp / xpReq)
            F().badgeBar:SetAnimatedValue(ratio)
            local pct = math.floor(ratio * 100)
            F().badgeFS:SetText(xp .. " / " .. xpReq .. " XP  " .. pct .. "%")
        end
        F().badgeBar:SetStatusBarColor(0.00, 0.70, 0.10, 1)
    end

    if F().titleFS then
        local XPM    = ArcadiaNexus.XPManager
        local prof   = ArcadiaNexusDB and ArcadiaNexusDB.profile or {}
        -- Aktiven Titel aus DB lesen; Fallback: höchster freigeschalteter Titel
        local activeTitle = prof.activeTitle
        local displayTitle
        if activeTitle then
            displayTitle = activeTitle
        else
            displayTitle = (XPM and XPM.GetTitle) and XPM:GetTitle(level) or "Arcade Initiate"
        end
        -- Sichtbarkeit respektieren
        local visible = (prof.titleVisible ~= false)
        if visible then
            F().titleFS:SetText(displayTitle)
            F().titleFS:SetTextColor(1.00, 0.82, 0.00)
            F().titleFS:Show()
        else
            F().titleFS:SetText("")
            F().titleFS:Hide()
        end
    end

    if F().gotdBox then
        local showBox = not (ArcadiaNexusDB and ArcadiaNexusDB.settings
            and ArcadiaNexusDB.settings.showGotd == false)
        if not showBox then
            F().gotdBox:Hide()
            return
        end
    end

    if F().streakFS then
        local SM = ArcadiaNexus.StreakManager
        local cur = SM and SM:GetCurrent() or
            (ArcadiaNexusDB and ArcadiaNexusDB.streak and ArcadiaNexusDB.streak.current) or 0
        F().streakFS:SetText((L("stats_streak") or "Login-Streak:") .. "  |TInterface\\Icons\\Spell_Fire_SealOfFire:14:14:0:0|t "
            .. cur .. " " .. (L("stats_days") or "Tage"))
    end

    if F().gotdFS then
        local CM = ArcadiaNexus.ChallengeManager
        local gotdId, gotdLabel = nil, nil
        if CM and CM.GetGameOfDay then
            gotdId = CM:GetGameOfDay()
            if gotdId then
                local GR = ArcadiaNexus.GameRegistry
                gotdLabel = GR and GR.GetLabel(gotdId) or gotdId
                F().gotdFS:SetText("GOTD: " .. gotdLabel)
            else
                F().gotdFS:SetText("GOTD")
            end
        else
            F().gotdFS:SetText("")
        end
        if F().gotdBtn then
            F().gotdBtn._gameId = gotdId
            if gotdId then F().gotdBtn:Enable() else F().gotdBtn:Disable() end
        end
        if F().gotdBox then
            F().gotdBox:Show()
        end
    end
end

ArcadiaNexus.Engine:On("XP_UPDATED", function()
    UpdateBadge()
end)

ArcadiaNexus.Engine:On("ARCADE_LEVEL_UP", function(data)
    if F().levelGlow and F().levelGlowAG then
        F().levelGlow:SetAlpha(1)
        F().levelGlowAG:Stop()
        F().levelGlowAG:Play()
    end
    if SOUNDKIT and SOUNDKIT.READY_CHECK then
        PlaySound(SOUNDKIT.READY_CHECK, "Master")
    end
    if F().titleFS then
        local newLevel = data and data.level or 1
        local newTitle = data and data.title or
            (ArcadiaNexus.XPManager and ArcadiaNexus.XPManager:GetTitle(newLevel)) or ""
        F().titleFS:SetText(string.format(
            (L("HEADER_LEVEL_UP") or "Arcade Level %d erreicht!"), newLevel))
        F().titleFS:SetTextColor(0.20, 1.00, 0.20)
        F().titleFS:Show()
        C_Timer.After(3.0, function()
            if F().titleFS then
                -- Nach Animation: aktiven Titel aus DB lesen
                local prof = ArcadiaNexusDB and ArcadiaNexusDB.profile or {}
                local displayTitle = prof.activeTitle or newTitle
                local visible = (prof.titleVisible ~= false)
                if visible then
                    F().titleFS:SetText(displayTitle)
                    F().titleFS:SetTextColor(1.00, 0.82, 0.00)
                    F().titleFS:Show()
                else
                    F().titleFS:SetText("")
                    F().titleFS:Hide()
                end
            end
        end)
    end
    UpdateBadge()
end)

ArcadiaNexus.UI.UpdateBadge    = UpdateBadge
