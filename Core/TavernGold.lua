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
    ArcadiaNexus.TavernGoldStore.Get()
end

-- ============================================================
-- API
-- ============================================================
function TG:Add(amount, reason)
    if not amount or amount <= 0 then return end
    local db = ArcadiaNexus.TavernGoldStore.Get()

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
    return ArcadiaNexus.TavernGoldStore.GetBalance()
end

function TG:GetLifetime()
    return ArcadiaNexus.TavernGoldStore.GetLifetime()
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
