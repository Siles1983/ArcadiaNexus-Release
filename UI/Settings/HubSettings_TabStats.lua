--[[
    ArcadiaNexus – HubSettings Tab: Statistiken
    UI/Settings/HubSettings_TabStats.lua

    Enthält:
        - JSON Encoder / Decoder (modul-lokal)
        - Base64 Encoder / Decoder (modul-lokal)
        - Export/Import Payload-Helfer
        - _BuildTabStats (Reset + Export/Import)
        - _ShowExportPopup
        - _ShowImportPopup
        - _ResetStats

    Abhängigkeiten:
        UI/Settings/HubSettings_Core.lua → ArcadiaNexus.HubSettings, _ShowConfirm
]]

local UI          = ArcadiaNexus.UI
local HubSettings = ArcadiaNexus.HubSettings

local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("UI")
    return tbl and tbl[key] or nil
end

-- ============================================================
-- JSON ENCODER / DECODER (Stats-intern)
-- ============================================================

local function _JsonEncode(val)
    local t = type(val)
    if val == nil then return "null"
    elseif t == "boolean" then return val and "true" or "false"
    elseif t == "number" then
        if val ~= val then return "null" end
        return tostring(val)
    elseif t == "string" then
        val = val:gsub("\\", "\\\\")
        val = val:gsub('"', '\\"'  )
        val = val:gsub("\n", "\\n" )
        val = val:gsub("\r", "\\r" )
        val = val:gsub("\t", "\\t" )
        return '"' .. val .. '"'
    elseif t == "table" then
        local isArray = true
        local maxN    = 0
        for k in pairs(val) do
            if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
                isArray = false; break
            end
            if k > maxN then maxN = k end
        end
        if isArray and maxN ~= #val then isArray = false end
        if isArray then
            local parts = {}
            for i = 1, #val do parts[i] = _JsonEncode(val[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, v in pairs(val) do
                if type(k) == "string" or type(k) == "number" then
                    table.insert(parts, _JsonEncode(tostring(k)) .. ":" .. _JsonEncode(v))
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

local function _JsonDecode(s)
    local pos = 1
    local function skip()
        while pos <= #s and s:sub(pos,pos):match("%s") do pos = pos + 1 end
    end
    local function peek() skip(); return s:sub(pos,pos) end
    local decode  -- forward declaration
    local function decodeString()
        pos = pos + 1
        local result = {}
        while pos <= #s do
            local c = s:sub(pos,pos)
            if c == "\\" then
                pos = pos + 1
                local esc = s:sub(pos,pos)
                if     esc == "n"  then table.insert(result, "\n")
                elseif esc == "r"  then table.insert(result, "\r")
                elseif esc == "t"  then table.insert(result, "\t")
                elseif esc == "\\" then table.insert(result, "\\")
                elseif esc == "/"  then table.insert(result, "/")
                elseif esc == '"'  then table.insert(result, '"')
                else                    table.insert(result, esc) end
            elseif c == '"' then
                pos = pos + 1; break
            else
                table.insert(result, c)
            end
            pos = pos + 1
        end
        return table.concat(result)
    end
    local function decodeNumber()
        local start = pos
        while pos <= #s and s:sub(pos,pos):match("[%d%.%-%+eE]") do pos = pos + 1 end
        return tonumber(s:sub(start, pos-1))
    end
    local function decodeArray()
        local arr = {}
        pos = pos + 1
        skip()
        if peek() == "]" then pos = pos + 1; return arr end
        repeat
            table.insert(arr, decode())
            skip()
            if peek() == "," then pos = pos + 1 end
        until peek() == "]" or pos > #s
        pos = pos + 1
        return arr
    end
    local function decodeObject()
        local obj = {}
        pos = pos + 1
        skip()
        if peek() == "}" then pos = pos + 1; return obj end
        repeat
            skip()
            local key = decodeString()
            skip()
            pos = pos + 1  -- skip :
            obj[key] = decode()
            skip()
            if peek() == "," then pos = pos + 1 end
        until peek() == "}" or pos > #s
        pos = pos + 1
        return obj
    end
    decode = function()
        skip()
        local c = peek()
        if     c == '"' then return decodeString()
        elseif c == "[" then return decodeArray()
        elseif c == "{" then return decodeObject()
        elseif c == "t" then pos = pos + 4; return true
        elseif c == "f" then pos = pos + 5; return false
        elseif c == "n" then pos = pos + 4; return nil
        else                 return decodeNumber() end
    end
    local ok, result = pcall(decode)
    if ok then return result else return nil, result end
end

-- ============================================================
-- BASE64 ENCODER / DECODER (Stats-intern)
-- ============================================================

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function _B64Encode(data)
    local res = {}
    local len = #data
    local i   = 1
    while i <= len do
        local b0 = data:byte(i) or 0
        local b1 = data:byte(i+1) or 0
        local b2 = data:byte(i+2) or 0
        local n  = b0*65536 + b1*256 + b2
        local s  = B64:sub(math.floor(n/262144)%64+1,math.floor(n/262144)%64+1)
                .. B64:sub(math.floor(n/4096)%64+1,  math.floor(n/4096)%64+1)
                .. B64:sub(math.floor(n/64)%64+1,    math.floor(n/64)%64+1)
                .. B64:sub(n%64+1, n%64+1)
        local rem = len - i + 1
        if rem == 1 then s = s:sub(1,2).."=="
        elseif rem == 2 then s = s:sub(1,3).."=" end
        table.insert(res, s)
        i = i + 3
    end
    return table.concat(res)
end

local B64_DEC = {}
for i = 1, #B64 do B64_DEC[B64:sub(i,i)] = i-1 end
B64_DEC["="] = 0

local function _B64Decode(data)
    data = data:gsub("[^%w%+%/%=]","")
    local res = {}
    local i   = 1
    while i <= #data do
        local c0 = B64_DEC[data:sub(i,i)]   or 0
        local c1 = B64_DEC[data:sub(i+1,i+1)] or 0
        local c2 = B64_DEC[data:sub(i+2,i+2)] or 0
        local c3 = B64_DEC[data:sub(i+3,i+3)] or 0
        local n  = c0*262144 + c1*4096 + c2*64 + c3
        table.insert(res, string.char(math.floor(n/65536)%256))
        if data:sub(i+2,i+2) ~= "=" then
            table.insert(res, string.char(math.floor(n/256)%256))
        end
        if data:sub(i+3,i+3) ~= "=" then
            table.insert(res, string.char(n%256))
        end
        i = i + 4
    end
    return table.concat(res)
end

-- ============================================================
-- EXPORT / IMPORT PAYLOAD-HELFER
-- ============================================================

local EXPORT_VERSION = "1.0"

local function _BuildExportPayload()
    if not ArcadiaNexusDB then return nil end
    local db = ArcadiaNexusDB
    return {
        version    = EXPORT_VERSION,
        exportedAt = GetServerTime(),
        leaderboard = db.leaderboard or {},
        profile     = db.profile     or {},
        streak      = db.streak      or {},
        challenges  = { history = (db.challenges and db.challenges.history) or {} },
    }
end

local function _ValidateImport(data)
    if type(data) ~= "table"  then return false, "Kein gültiges Datenformat." end
    if data.version ~= EXPORT_VERSION then
        return false, "Ungültige Version: " .. tostring(data.version)
    end
    if type(data.leaderboard) ~= "table" then return false, "leaderboard fehlt." end
    if type(data.profile)     ~= "table" then return false, "profile fehlt."     end
    if type(data.streak)      ~= "table" then return false, "streak fehlt."      end
    return true
end

local function _ApplyImport(data)
    ArcadiaNexusDB.leaderboard = data.leaderboard
    ArcadiaNexusDB.profile     = data.profile
    ArcadiaNexusDB.streak      = data.streak
    if data.challenges and data.challenges.history then
        if not ArcadiaNexusDB.challenges then ArcadiaNexusDB.challenges = {} end
        ArcadiaNexusDB.challenges.history = data.challenges.history
    end
    if ArcadiaNexus.XPManager    and ArcadiaNexus.XPManager.Refresh    then
        pcall(function() ArcadiaNexus.XPManager:Refresh() end) end
    if ArcadiaNexus.StreakManager and ArcadiaNexus.StreakManager.Refresh then
        pcall(function() ArcadiaNexus.StreakManager:Refresh() end) end
    GH_LogInfo("HubSettings", "Import erfolgreich angewendet.")
end

-- ============================================================
-- TAB: STATISTIKEN
-- ============================================================

function HubSettings:_BuildTabStats(parent)
    local GAP = 12
    local P   = UI.BOX_PAD

    -- ── BOX: Statistiken zurücksetzen ────────────────────────
    local BOX_H_RESET = 100
    local resetBox, resetContent = UI.CreateBox(parent,
        L("hubsettings_stats_section") or "Statistiken zurücksetzen",
        P, 0, 0, BOX_H_RESET, P)

    local resetDesc = resetContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetDesc:SetPoint("TOPLEFT", resetContent, "TOPLEFT", 0, 0)
    resetDesc:SetPoint("RIGHT",   resetContent, "RIGHT",   0, 0)
    resetDesc:SetJustifyH("LEFT")
    resetDesc:SetWordWrap(true)
    resetDesc:SetText(L("hubsettings_stats_reset_desc") or
        "Setzt Bestenliste, Profil, Streak und Challenges zurück. Erfolge bleiben erhalten.")
    resetDesc:SetTextColor(0.75, 0.70, 0.55)

    local statsResetBtn = UI.CreateButton(resetContent, L("hubsettings_stats_reset_btn") or "Statistiken zurücksetzen", 220, 26)
    statsResetBtn:SetPoint("TOPLEFT", resetDesc, "BOTTOMLEFT", 0, -10)
    statsResetBtn:SetScript("OnClick", function()
        HubSettings:_ShowConfirm(
            L("hubsettings_stats_confirm1_title") or "Statistiken zurücksetzen?",
            L("hubsettings_stats_confirm1_body")  or
                "Bestenliste, Profil, Streak und Challenges werden unwiderruflich gelöscht. Fortfahren?",
            function()
                HubSettings:_ShowConfirm(
                    L("hubsettings_stats_confirm2_title") or "Wirklich zurücksetzen?",
                    L("hubsettings_stats_confirm2_body")  or
                        "Letzte Warnung: Alle Statistiken werden auf Startwerte gesetzt.",
                    function() HubSettings:_ResetStats() end
                )
            end
        )
    end)

    -- ── BOX: Export / Import ──────────────────────────────────
    local BOX_H_EXP = 90
    local exportBox, exportContent = UI.CreateBox(parent,
        L("hubsettings_export_section") or "Export / Import",
        P, BOX_H_RESET + GAP, 0, BOX_H_EXP, P)

    local expDesc = exportContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expDesc:SetPoint("TOPLEFT", exportContent, "TOPLEFT", 0, 0)
    expDesc:SetPoint("RIGHT",   exportContent, "RIGHT",   0, 0)
    expDesc:SetJustifyH("LEFT")
    expDesc:SetWordWrap(true)
    expDesc:SetText(
        L("hubsettings_export_desc") or
        "Bestenliste, Profil, Streak und Challenge-Verlauf exportieren oder importieren.")
    expDesc:SetTextColor(0.75, 0.70, 0.55)

    local exportBtn = UI.CreateButton(exportContent, L("hubsettings_export_btn") or "Exportieren", 150, 26)
    exportBtn:SetPoint("TOPLEFT", expDesc, "BOTTOMLEFT", 0, -10)
    exportBtn:SetScript("OnClick", function()
        local payload = _BuildExportPayload()
        if not payload then return end
        local b64 = _B64Encode(_JsonEncode(payload))
        HubSettings:_ShowExportPopup(b64)
    end)

    local importBtn = UI.CreateButton(exportContent, L("hubsettings_import_btn") or "Importieren", 150, 26)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
    importBtn:SetScript("OnClick", function()
        HubSettings:_ShowImportPopup()
    end)
end

-- ============================================================
-- EXPORT POPUP
-- ============================================================

function HubSettings:_ShowExportPopup(b64String)
    if not self._exportPopup then
        local d = CreateFrame("Frame", "NexusExportPopup", UIParent, "BackdropTemplate")
        d:SetSize(520, 200)
        d:SetFrameStrata("DIALOG")
        d:SetFrameLevel(700)
        d:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        d:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileEdge=true, edgeSize=16,
            insets={left=5,right=5,top=5,bottom=5},
        })
        d:SetBackdropColor(0.06, 0.05, 0.03, 0.96)
        d:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)

        local titleFS = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleFS:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -14)
        titleFS:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -14)
        titleFS:SetJustifyH("CENTER")
        titleFS:SetTextColor(1.00, 0.82, 0.00)
        titleFS:SetText(L("hubsettings_export_popup_title") or "Statistiken exportieren")

        local hint = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -34)
        hint:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -34)
        hint:SetJustifyH("CENTER")
        hint:SetTextColor(0.75, 0.70, 0.55)
        hint:SetText(L("hubsettings_export_popup_hint") or "Den String kopieren und sicher aufbewahren.")

        local ebFrame = CreateFrame("Frame", nil, d, "BackdropTemplate")
        ebFrame:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -54)
        ebFrame:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -54)
        ebFrame:SetHeight(88)
        ebFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileEdge=true, edgeSize=10,
            insets={left=3,right=3,top=3,bottom=3},
        })
        ebFrame:SetBackdropColor(0.04, 0.04, 0.04, 0.98)
        ebFrame:SetBackdropBorderColor(0.45, 0.38, 0.16, 1)

        local eb = CreateFrame("EditBox", nil, ebFrame)
        eb:SetPoint("TOPLEFT",     ebFrame, "TOPLEFT",     5, -5)
        eb:SetPoint("BOTTOMRIGHT", ebFrame, "BOTTOMRIGHT", -5,  5)
        eb:SetMultiLine(false)
        eb:SetAutoFocus(false)
        eb:SetFontObject("ChatFontNormal")
        eb:SetMaxLetters(0)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        d._eb = eb

        local copyBtn = UI.CreateButton(d, L("hubsettings_export_copy") or "Alles markieren", 160, 26)
        copyBtn:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 14, 12)
        copyBtn:SetScript("OnClick", function()
            d._eb:SetFocus()
            d._eb:HighlightText()
        end)

        local closeBtn = UI.CreateButton(d, L("hubsettings_export_close") or "Schließen", 120, 26)
        closeBtn:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 12)
        closeBtn:SetScript("OnClick", function() d:Hide() end)

        self._exportPopup = d
    end

    self._exportPopup._eb:SetText(b64String)
    C_Timer.After(0, function()
        if self._exportPopup._eb then
            self._exportPopup._eb:SetFocus()
            self._exportPopup._eb:HighlightText()
        end
    end)
    self._exportPopup:Show()
end

-- ============================================================
-- IMPORT POPUP
-- ============================================================

function HubSettings:_ShowImportPopup()
    if not self._importPopup then
        local d = CreateFrame("Frame", "NexusImportPopup", UIParent, "BackdropTemplate")
        d:SetSize(520, 220)
        d:SetFrameStrata("DIALOG")
        d:SetFrameLevel(700)
        d:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        d:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileEdge=true, edgeSize=16,
            insets={left=5,right=5,top=5,bottom=5},
        })
        d:SetBackdropColor(0.06, 0.05, 0.03, 0.96)
        d:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)

        local titleFS = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleFS:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -14)
        titleFS:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -14)
        titleFS:SetJustifyH("CENTER")
        titleFS:SetTextColor(1.00, 0.82, 0.00)
        titleFS:SetText(L("hubsettings_import_popup_title") or "Statistiken importieren")

        local hint = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -34)
        hint:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -34)
        hint:SetJustifyH("CENTER")
        hint:SetTextColor(0.75, 0.70, 0.55)
        hint:SetText(L("hubsettings_import_popup_hint") or "Export-String einfügen und Importieren klicken.")

        local statusFS = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusFS:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -48)
        statusFS:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -48)
        statusFS:SetJustifyH("CENTER")
        statusFS:SetText("")
        d._statusFS = statusFS

        local ebFrame = CreateFrame("Frame", nil, d, "BackdropTemplate")
        ebFrame:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -62)
        ebFrame:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -62)
        ebFrame:SetHeight(90)
        ebFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileEdge=true, edgeSize=10,
            insets={left=3,right=3,top=3,bottom=3},
        })
        ebFrame:SetBackdropColor(0.04, 0.04, 0.04, 0.98)
        ebFrame:SetBackdropBorderColor(0.45, 0.38, 0.16, 1)

        local eb = CreateFrame("EditBox", nil, ebFrame)
        eb:SetPoint("TOPLEFT",     ebFrame, "TOPLEFT",     5, -5)
        eb:SetPoint("BOTTOMRIGHT", ebFrame, "BOTTOMRIGHT", -5,  5)
        eb:SetMultiLine(false)
        eb:SetAutoFocus(false)
        eb:SetFontObject("ChatFontNormal")
        eb:SetMaxLetters(0)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        d._eb = eb

        local confirmBtn = UI.CreateButton(d, L("hubsettings_import_confirm_btn") or "Importieren", 160, 26)
        confirmBtn:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 14, 12)
        confirmBtn:SetScript("OnClick", function()
            local raw = d._eb:GetText()
            if not raw or raw == "" then
                d._statusFS:SetText("|cffff4444Kein Text eingefügt.|r")
                return
            end
            local ok, jsonStr = pcall(_B64Decode, raw)
            if not ok or not jsonStr then
                d._statusFS:SetText("|cffff4444Ungültiger Export-String.|r")
                return
            end
            local data, err = _JsonDecode(jsonStr)
            if not data then
                d._statusFS:SetText("|cffff4444JSON-Fehler: " .. tostring(err) .. "|r")
                return
            end
            local valid, validErr = _ValidateImport(data)
            if not valid then
                d._statusFS:SetText("|cffff4444Fehler: " .. validErr .. "|r")
                return
            end
            d:Hide()
            HubSettings:_ShowConfirm(
                L("hubsettings_import_confirm_title") or "Statistiken importieren?",
                L("hubsettings_import_confirm_body")  or
                    "Aktuelle Statistiken werden überschrieben. Fortfahren?",
                function()
                    _ApplyImport(data)
                    d._eb:SetText("")
                    d._statusFS:SetText("")
                end
            )
        end)

        local cancelBtn = UI.CreateButton(d, L("hubsettings_import_cancel") or "Abbrechen", 120, 26)
        cancelBtn:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 12)
        cancelBtn:SetScript("OnClick", function()
            d._eb:SetText("")
            d._statusFS:SetText("")
            d:Hide()
        end)

        self._importPopup = d
    end

    self._importPopup._eb:SetText("")
    self._importPopup._statusFS:SetText("")
    self._importPopup:Show()
    C_Timer.After(0, function()
        if self._importPopup._eb then self._importPopup._eb:SetFocus() end
    end)
end

-- ============================================================
-- STATISTIKEN ZURÜCKSETZEN
-- ============================================================

function HubSettings:_ResetStats()
    if not ArcadiaNexusDB then return end
    ArcadiaNexusDB.leaderboard = {}
    ArcadiaNexusDB.profile = {
        level=1, xp=0, xpRequired=2000, totalXP=0,
        totalGames=0, wins=0, losses=0, draws=0,
    }
    ArcadiaNexusDB.streak     = { current=0, best=0, lastLogin=0, claimedToday=false }
    ArcadiaNexusDB.challenges = {
        daily={}, weekly={},
        history={ completedTotal=0, goldEarned=0 },
    }
    if ArcadiaNexus.XPManager     and ArcadiaNexus.XPManager.Refresh     then
        pcall(function() ArcadiaNexus.XPManager:Refresh() end) end
    if ArcadiaNexus.StreakManager  and ArcadiaNexus.StreakManager.Refresh  then
        pcall(function() ArcadiaNexus.StreakManager:Refresh() end) end

    GH_LogInfo("HubSettings", "Statistiken wurden zurückgesetzt.")

    local TM = ArcadiaNexus.ToastManager
    if TM and TM.Show then
        pcall(function()
            TM:Show({
                icon     = "Interface\\Icons\\Achievement_General_StayClassy",
                title_de = "Statistiken zurückgesetzt",
                title_en = "Statistics Reset",
                desc_de  = "Alle Statistiken wurden auf Startwerte gesetzt.",
                desc_en  = "All statistics have been reset.",
            })
        end)
    end
end

-- ============================================================
-- REGISTRY
-- ============================================================

ArcadiaNexus.RegisterHubSettingsTab({
    id            = "STATS",
    labelKey      = "hubsettings_tab_stats",
    labelFallback = "Statistiken",
    order         = 30,
    buildContent  = function(parent)
        HubSettings:_BuildTabStats(parent)
    end,
})
