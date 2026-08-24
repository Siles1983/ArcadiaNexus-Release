--[[
    Ludo of Azeroth – Debug.lua
    Positions-Kalibrierung per Slash-Command.

    /loa              – Hilfe
    /loa debug        – Freies Klicken (Koordinaten in Chat)
    /loa debug path   – Geführtes Mapping aller Felder
    /loa debug export – Lua-Tabelle ausgeben
    /loa debug clear  – Marker entfernen
    /loa debug off    – Debug-Modus beenden
    /loa npc          – NPC unter dem Mauszeiger auslesen (creatureID + displayID)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LOA_Debug = {}
local D = ArcadiaNexus.LOA_Debug

D.active       = false
D.mode         = nil       -- "free" | "guided"
D._renderer    = nil
D._markers     = {}
D._guidedSteps = nil
D._guidedIdx   = 0

local PREFIX = "|cff00ccff[LOA Debug]|r"

local function Print(msg)
    print(PREFIX .. " " .. msg)
end

local function BuildGuidedSteps()
    local Pos = ArcadiaNexus.LOA_Positions
    local steps = {}

    for i = 1, 40 do
        steps[#steps+1] = {
            type  = "main",
            idx   = i,
            label = string.format("Hauptpfad Feld %d/40", i),
        }
    end

    for c = 1, 4 do
        local cname = Pos.COLOR_NAMES[c] or tostring(c)
        for s = 1, 4 do
            steps[#steps+1] = {
                type     = "home",
                colorIdx = c,
                idx      = s,
                label    = string.format("Zielgerade %s – Feld %d/4", cname, s),
            }
        end
    end

    for c = 1, 4 do
        local cname = Pos.COLOR_NAMES[c] or tostring(c)
        for s = 1, 4 do
            steps[#steps+1] = {
                type     = "base",
                colorIdx = c,
                idx      = s,
                label    = string.format("Basis %s – Slot %d/4", cname, s),
            }
        end
    end

    steps[#steps+1] = { type = "dice", label = "Würfel-Position" }
    return steps
end

function D:Init(renderer)
    self._renderer = renderer
end

function D:GetLocalCoords(fieldFrame)
    if not fieldFrame then return 0, 0 end
    local x, y = GetCursorPosition()
    local scale = fieldFrame:GetEffectiveScale()
    x, y = x / scale, y / scale
    local left, bottom, width, height = fieldFrame:GetRect()
    local top = bottom + height
    local localX = math.floor(x - left + 0.5)
    local localY = math.floor(top - y + 0.5)
    return localX, localY
end

function D:ClearMarkers()
    for _, m in ipairs(self._markers) do
        if m.frame then
            m.frame:Hide()
            m.frame:SetParent(nil)
        end
    end
    self._markers = {}
end

function D:PlaceMarker(fieldFrame, pos, label)
    if not fieldFrame or not pos then return end
    local marker = CreateFrame("Frame", nil, fieldFrame)
    marker:SetSize(12, 12)
    marker:SetPoint("CENTER", fieldFrame, "TOPLEFT", pos.x, -pos.y)
    marker:SetFrameLevel(fieldFrame:GetFrameLevel() + 50)

    local tex = marker:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetVertexColor(1, 0.2, 0.2, 0.85)

    if label then
        local fs = marker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("BOTTOM", marker, "TOP", 0, 2)
        fs:SetText(label)
        fs:SetTextColor(1, 0.85, 0.3)
    end

    marker:Show()
    self._markers[#self._markers+1] = { frame = marker, pos = pos, label = label }
end

function D:ApplyPos(step, pos)
    local Pos = ArcadiaNexus.LOA_Positions
    if step.type == "main" then
        Pos:SetMain(step.idx, pos)
    elseif step.type == "home" then
        Pos:SetHome(step.colorIdx, step.idx, pos)
    elseif step.type == "base" then
        Pos:SetBase(step.colorIdx, step.idx, pos)
    elseif step.type == "dice" then
        Pos:SetDice(pos)
    end
end

function D:PrintStepPrompt()
    if self.mode ~= "guided" or not self._guidedSteps then return end
    local step = self._guidedSteps[self._guidedIdx]
    if not step then
        Print("|cff00ff00Kalibrierung abgeschlossen!|r /loa debug export")
        self:Stop()
        return
    end
    Print(string.format(
        "|cffffff00[%d/%d]|r %s – Klicke auf die Position.",
        self._guidedIdx, #self._guidedSteps, step.label))
end

function D:OnFieldClick(fieldFrame)
    if not self.active or not fieldFrame then return end
    local x, y = self:GetLocalCoords(fieldFrame)
    local pos  = { x = x, y = y }

    if self.mode == "free" then
        Print(string.format("{ x = %d, y = %d }", x, y))
        self:PlaceMarker(fieldFrame, pos, nil)
        return
    end

    if self.mode == "guided" and self._guidedSteps then
        local step = self._guidedSteps[self._guidedIdx]
        if not step then return end

        self:ApplyPos(step, pos)
        self:PlaceMarker(fieldFrame, pos, tostring(self._guidedIdx))

        local key
        if step.type == "main" then
            key = string.format("MAIN[%d]", step.idx)
        elseif step.type == "home" then
            key = string.format("HOME[%d][%d]", step.colorIdx, step.idx)
        elseif step.type == "base" then
            key = string.format("BASE[%d][%d]", step.colorIdx, step.idx)
        else
            key = "DICE"
        end

        Print(string.format("%s = { x = %d, y = %d }", key, x, y))
        self._guidedIdx = self._guidedIdx + 1
        self:PrintStepPrompt()

        if self._renderer then
            if self._renderer._game then
                self._renderer:RenderAllPieces(self._renderer._game)
                self._renderer:PositionDice(self._renderer._game)
            end
            self._renderer:RefreshDevPosOverlay()
        end
    end
end

function D:StartFree()
    self.active = true
    self.mode   = "free"
    self._guidedSteps = nil
    self._guidedIdx   = 0
    Print("Freier Modus – klicke aufs Spielfeld. /loa debug off zum Beenden.")
    if self._renderer then self._renderer:SetDebugOverlay(true) end
end

function D:StartGuided()
    self.active       = true
    self.mode         = "guided"
    self._guidedSteps = BuildGuidedSteps()
    self._guidedIdx   = 1
    self:ClearMarkers()
    Print("Geführter Modus – " .. #self._guidedSteps .. " Punkte.")
    self:PrintStepPrompt()
    if self._renderer then self._renderer:SetDebugOverlay(true) end
end

function D:Stop()
    self.active       = false
    self.mode         = nil
    self._guidedSteps = nil
    self._guidedIdx   = 0
    if self._renderer then self._renderer:SetDebugOverlay(false) end
    Print("Debug-Modus beendet.")
end

function D:Export()
    local Pos = ArcadiaNexus.LOA_Positions
    local text = Pos:ExportLua()
    Print("--- Export (in LOA_Positions.lua einfügen) ---")
    for line in text:gmatch("[^\n]+") do
        print(PREFIX .. " " .. line)
    end
    Print("--- Ende Export ---")
end

function D:HandleCommand(input)
    local cmd = (input or ""):lower():match("^%s*(.-)%s*$") or ""

    if cmd == "" or cmd == "help" then
        Print("Befehle: debug | debug path | debug export | debug clear | debug off | dice3d | npc")
        return
    end

    if cmd == "npc" then
        local creatureID
        if UnitExists("mouseover") then
            creatureID = UnitCreatureId("mouseover")
        elseif UnitExists("target") then
            creatureID = UnitCreatureId("target")
        end
        if not creatureID or creatureID <= 0 then
            Print("Kein NPC unter Mauszeiger/Ziel. Orc anvisieren und erneut /loa npc.")
            return
        end
        local Npc = ArcadiaNexus.LOA_NpcData
        local info = Npc and Npc:DumpCreatureInfo(creatureID)
        if info and info.cached then
            Print(string.format("NPC %d – %s – displayID %d", creatureID, info.name or "?", info.displayID or 0))
        else
            Print(string.format("NPC %d – noch nicht im Cache. Einmal anvisieren/warten, dann erneut /loa npc.", creatureID))
        end
        return
    end

    if cmd == "dice3d" then
        local R = self._renderer or ArcadiaNexus.LOA_Renderer
        local Dice = ArcadiaNexus.LOA_Dice
        if R and Dice and R._diceScene then
            if R._diceFrame then R._diceFrame:Show() end
            Dice:DebugProbe(R._diceScene, R)
        else
            Print("Würfel-UI noch nicht initialisiert – LOA-Fenster öffnen.")
        end
        return
    end

    if cmd == "debug" then
        if self.active and self.mode == "free" then
            self:Stop()
        else
            self:StartFree()
        end
        return
    end

    if cmd == "debug path" then
        self:StartGuided()
        return
    end

    if cmd == "debug export" then
        self:Export()
        return
    end

    if cmd == "debug clear" then
        self:ClearMarkers()
        Print("Marker entfernt.")
        return
    end

    if cmd == "debug off" then
        self:Stop()
        self:ClearMarkers()
        return
    end

    Print("Unbekannter Befehl. /loa help")
end

SLASH_LOA1 = "/loa"
SlashCmdList["LOA"] = function(msg)
    ArcadiaNexus.LOA_Debug:HandleCommand(msg)
end
