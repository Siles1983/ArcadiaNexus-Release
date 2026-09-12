--[[
    Vorzeige-Draft: Rampe, Kiste, Rohr-Nebenraum, Checkpoint,
    Schwimmen, Schalter/Tuer, Foerderband, Trampolin, Geheim-Muenze.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LevelEditorSample = {}
local Sample = ArcadiaNexus.LevelEditorSample

function Sample.Showcase()
    local Ser = ArcadiaNexus.LevelEditorSerialize
    local Cat = ArcadiaNexus.LevelEditorCatalog
    local d = Ser.Blank(56, 18)
    d.name = "Showcase"
    d.game = Cat and Cat.GAME_AA or "AZEROTH_ASCENT"
    d.theme = "day"
    d.parallax = "theme"

    local function row(r, s)
        d.rows[r] = s
    end

    -- 56 Zeichen. Boden in Zeile 17, Spawn/Goal in 16.
    row(4,  "............IIII............................................")
    row(5,  "............#..#.....wwww...................................")
    row(6,  "............#C.#.....wwww...................................")
    row(7,  "............#..#.....####...................................")
    row(8,  "............IIII............................................")
    row(16, "..P....../\\....=..=....k....>>>>..j....s.D.....z...E..G.")
    row(17, "############################################################")
    -- Blank pads/truncates; force width 56
    for r = 1, d.height do
        local line = d.rows[r] or ""
        if #line < 56 then
            line = line .. string.rep(".", 56 - #line)
        elseif #line > 56 then
            line = line:sub(1, 56)
        end
        d.rows[r] = line
    end
    d.width = 56

    Ser.Set(d, 13, 4, "I", { pair = 1 })
    Ser.Set(d, 13, 8, "I", { pair = 1 })
    Ser.Set(d, 16, 4, "I", { pair = 1 })
    Ser.Set(d, 16, 8, "I", { pair = 1 })
    Ser.Set(d, 40, 16, "s", { pair = 2 })
    Ser.Set(d, 42, 16, "D", { pair = 2 })
    Ser.Set(d, 52, 16, "E", { patrol = 4, behavior = "turn" })
    Ser.SetProp(d, 12, 16, "crate", {})
    Ser.SetProp(d, 28, 10, "camlock", { cam = "xy", span = 4 })
    Ser.SetProp(d, 22, 14, "wind", { axis = "h", span = 4 })

    -- Schluessel im Nebenraum
    Ser.Set(d, 14, 6, "U", { pair = 2 })
    Ser.Set(d, 11, 16, "/", {})
    Ser.Set(d, 12, 16, "\\", {})

    return Ser.ToEntry(d)
end
