-- Public Match callback contract. No transport or lobby implementation.
local A, L = ArcadiaNexus, ArcadiaNexus.BG_Logic
A.BG_Match = {}
function A.BG_Match.Options(engine, rng)
    return {
        gameId = L.GAME_ID, gameProto = L.GAME_PROTO, maxSeats = 2,
        newPublic = L.New, seedOnStart = L.New,
        packPublic = function(s) return { bg = L.Serialize(s) } end,
        -- START carries seats only, so a replay cannot reset an advanced board.
        unpackPublic = function(s, fields)
            local incoming = L.Deserialize(fields.bg)
            if not incoming or incoming.revision < s.revision then return end
            for k, v in pairs(incoming) do s[k] = v end
        end,
        privateForSeat = function() return nil end,
        applyIntent = function(s, intent, seat) return L.Apply(s, intent, seat, rng) end,
        isFinished = function(s) return s.winner ~= 0 end,
        onState = function(node, state) if engine then engine:OnMatchState(node, state) end end,
        onPublic = function(node) if engine then engine:OnMatchPublic(node) end end,
        onResult = function(node, id) if engine then engine:OnMatchResult(node, id) end end,
        onReject = function(node, fields) if engine then engine:OnMatchReject(fields, node) end end,
    }
end
