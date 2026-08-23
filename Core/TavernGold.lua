--[[
    ArcadiaNexus – TavernGold
    Core/TavernGold.lua
    Kosmetische Währung (Äquivalent zu Kriegsmeutenerfolgspunkten).
    Wird vergeben, nicht ausgegeben — alle Gutschriften laufen hier durch.
    Emittiert GOLD_UPDATED nach jeder Änderung.
]]

local TG = {}
ArcadiaNexus.TavernGold = TG

-- Maximale Log-Einträge
local MAX_LOG = 20

-- ============================================================
-- INIT
-- ============================================================
function TG:Init()
    if not ArcadiaNexusDB.tavernGold then
        ArcadiaNexusDB.tavernGold = { balance=0, lifetime=0, log={} }
    end
    local db = ArcadiaNexusDB.tavernGold
    if not db.log      then db.log      = {} end
    if not db.lifetime then db.lifetime = 0  end
    if not db.balance  then db.balance  = 0  end
end

-- ============================================================
-- API
-- ============================================================
function TG:Add(amount, reason)
    if not amount or amount <= 0 then return end
    local db = ArcadiaNexusDB.tavernGold
    if not db then return end

    db.balance  = (db.balance  or 0) + amount
    db.lifetime = (db.lifetime or 0) + amount

    -- Log (FIFO, max 20)
    table.insert(db.log, { amount=amount, reason=reason or "unknown", time=GetServerTime() })
    while #db.log > MAX_LOG do table.remove(db.log, 1) end

    ArcadiaNexus.Engine:Emit("GOLD_UPDATED", { balance=db.balance, delta=amount, reason=reason })

    -- Toast für Gold-Gewinn
    local TM = ArcadiaNexus.ToastManager
    if TM and TM.ShowGold then
        pcall(function() TM:ShowGold(amount, reason) end)
    end
end

function TG:GetBalance()
    return (ArcadiaNexusDB.tavernGold and ArcadiaNexusDB.tavernGold.balance) or 0
end

function TG:GetLifetime()
    return (ArcadiaNexusDB.tavernGold and ArcadiaNexusDB.tavernGold.lifetime) or 0
end

-- ============================================================
-- Gold aus Achievement-XP-Wert berechnen (5–50 Gold)
-- Wird von AchievementManager aufgerufen
-- ============================================================
function TG:GoldFromXP(xpValue)
    if not xpValue or xpValue <= 0 then return 0 end
    -- Lineare Skalierung: 50 XP → 5 Gold, 500 XP → 50 Gold
    local gold = math.floor(xpValue / 10)
    return math.max(5, math.min(50, gold))
end
