--[[
    ArcadiaNexus – Core/AchievementIcons.lua
    Zentrale Icon-Hilfen für Achievement-Definitionen und UI.

    API:
      ArcadiaNexus.AchievementIcons.FALLBACK_PATH
      ArcadiaNexus.AchievementIcons.FALLBACK_FILE_ID
      ArcadiaNexus.AchievementIcons.IsValid(icon)
      ArcadiaNexus.AchievementIcons.Normalize(icon, groupId?)
      ArcadiaNexus.AchievementIcons.ApplyToTexture(texture, icon)
      ArcadiaNexus.AchievementIcons.AuditAll() → { issues, total }
]]

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.AchievementIcons = {}

local AI = ArcadiaNexus.AchievementIcons

AI.FALLBACK_PATH     = "Interface/Icons/INV_Misc_QuestionMark"
AI.FALLBACK_FILE_ID  = 134400

local ICON_TEX_COORD = { 0.08, 0.92, 0.08, 0.92 }

local PLACEHOLDER_PATTERNS = {
    "^Interface/Icons/INV_Misc_QuestionMark$",
    "^Interface\\Icons\\INV_Misc_QuestionMark$",
}

--- Prüft ob ein Icon-Wert gesetzt und plausibel ist (Roh-Definition).
function AI:IsValid(icon)
    if icon == nil or icon == false then return false end
    if type(icon) == "number" then
        return icon > 0
    end
    if type(icon) ~= "string" then return false end
    local trimmed = icon:match("^%s*(.-)%s*$")
    if trimmed == "" or trimmed == "0" then return false end
    for _, pat in ipairs(PLACEHOLDER_PATTERNS) do
        if trimmed:match(pat) then return false end
    end
    if trimmed:match("^Interface") then
        return trimmed:match("[Ii]cons") ~= nil
    end
    -- Kurzname ohne Pfad (z. B. "INV_Misc_Coin_01")
    return trimmed:match("^[%w_]+$") ~= nil
end

--- Wandelt Roh-Icon in FileDataID oder Interface/Icons/-Pfad um.
function AI:Normalize(icon, groupId)
    if type(icon) == "number" and icon > 0 then
        return icon
    end

    if type(icon) == "string" then
        local path = icon:match("^%s*(.-)%s*$")
        if path ~= "" then
            path = path:gsub("\\", "/")
            path = path:gsub("/+", "/")

            if not path:match("^Interface/") then
                path = path:gsub("^/", "")
                path = "Interface/Icons/" .. path
            end

            if self:IsValid(path) or path:match("^Interface/Icons/") then
                return path
            end
        end
    end

    if groupId then
        GH_LogWarn("AchievementIcons", "Fallback-Icon für '" .. tostring(groupId) .. "'")
    end
    return self.FALLBACK_PATH
end

--- Setzt ein Icon sicher auf eine Textur (Pfad oder FileDataID).
function AI:ApplyToTexture(texture, icon)
    if not texture or not texture.SetTexture then return end

    local validIcon = self:Normalize(icon)
    local success   = texture:SetTexture(validIcon)

    if success == nil or success == false then
        if not texture:GetTexture() then
            texture:SetTexture(self.FALLBACK_FILE_ID)
        end
    end

    texture:SetTexCoord(ICON_TEX_COORD[1], ICON_TEX_COORD[2], ICON_TEX_COORD[3], ICON_TEX_COORD[4])
    texture:Show()
end

--- Durchläuft alle registrierten Achievement-Gruppen und meldet Probleme.
function AI:AuditAll()
    return self:AuditRegistered()
end

--- Normalisiert alle Icons in AchievementData (nach Index-Aggregation).
function AI:NormalizeAllRegistered()
    local data = ArcadiaNexus.AchievementData
    if not data then return end
    local issues = {}
    for _, group in ipairs(data) do
        group._iconRaw = group.icon
        if not self:IsValid(group.icon) then
            issues[#issues + 1] = {
                id     = group.id or "?",
                gameId = group.gameId,
                icon   = group.icon,
            }
        end
        group.icon = self:Normalize(group.icon, group.id)
    end
    ArcadiaNexus._achievementIconAudit = issues
end

--- Prüft registrierte Achievements anhand der Original-Icon-Werte.
function AI:AuditRegistered()
    local data   = ArcadiaNexus.AchievementData or {}
    local issues = {}
    for _, group in ipairs(data) do
        local raw = group._iconRaw or group.icon
        if not self:IsValid(raw) then
            issues[#issues + 1] = {
                id     = group.id or "?",
                gameId = group.gameId,
                icon   = raw,
            }
        end
    end
    return { issues = issues, total = #data, issueCount = #issues }
end
