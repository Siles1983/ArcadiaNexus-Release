--[[
    ArcadiaNexus – Core/Match/Dummy.lua
    Spielagnostisches Dummy-Spiel: TAP erhöht einen Zähler. Sitze 1+2
    erhalten ein Secret, 3+4 nicht.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.MatchDummy = {}
local D = ArcadiaNexus.MatchDummy

D.GAME_ID = "DUMMY"
D.GAME_PROTO = 1
D.GOAL = 3

function D.NewPublic()
    return { count = 0, lastSeat = 0 }
end

function D.ApplyIntent(public, intent, seat)
    if not intent or intent.kind ~= "TAP" then
        return false, "bad-kind"
    end
    public.count = (public.count or 0) + 1
    public.lastSeat = seat
    return true
end

function D.IsFinished(public)
    return (public.count or 0) >= D.GOAL
end

--- Sitze 1 und 2 sehen Hidden-Info (Zahl, keine Tabellenkeys).
function D.PrivateForSeat(seat)
    if seat == 1 or seat == 2 then
        return 1
    end
    return nil
end
