-- Pure clue rules for the M6 prototype. Runtime integration follows its gate.
local A = _G.ArcadiaNexus
local C = {}
A.SI7_Clues = C
C.VERSION = 2

local replacements = {
    { "ä", "AE" }, { "Ä", "AE" }, { "ö", "OE" }, { "Ö", "OE" },
    { "ü", "UE" }, { "Ü", "UE" }, { "ß", "SS" }, { "ẞ", "SS" },
}
function C.Normalize(text)
    if type(text) ~= "string" then return nil, "clue_chars" end
    text = text:match("^%s*(.-)%s*$")
    if text == "" then return nil, "clue_empty" end
    if text:find("%s") then return nil, "clue_words" end
    for _, pair in ipairs(replacements) do text = text:gsub(pair[1], pair[2]) end
    text = string.upper(text)
    if not text:match("^[A-Z]+$") then return nil, "clue_chars" end
    if #text > 16 then return nil, "clue_long" end
    return text
end

function C.IsInteger(value, low, high)
    return type(value) == "number" and value == value and value >= low
        and value <= high and value == math.floor(value)
end

-- Stable AZEROTH concept IDs; compare both localizations, even for hidden cards.
function C.PrepareBoard(ids)
    if type(ids) ~= "table" or #ids ~= 25 then return nil, "board_invalid" end
    local words, forms, seen = A.HGM_Words, {}, {}
    for i = 1, 25 do
        if type(ids[i]) ~= "string" or seen[ids[i]] then return nil, "board_invalid" end
        seen[ids[i]] = true
        for _, locale in ipairs({ "deDE", "enUS" }) do
            local boardWord = words:GetLocalizedWord(ids[i], locale)
            if not boardWord then return nil, "board_invalid" end
            -- Input stays strictly one word. A compact spelling must not bypass
            -- the board-word ban for cards such as C'Thun or Molten Core.
            -- Strip display separators only here, never in clue input.
            local normalized = C.Normalize(boardWord:gsub("[%s'%-]", ""))
            if normalized then forms[normalized] = true end
        end
    end
    return forms
end

function C.ValidatePrepared(forms, text)
    local clue, reason = C.Normalize(text)
    if not clue then return nil, reason end
    if type(forms) ~= "table" then return nil, "board_invalid" end
    if forms[clue] then return nil, "clue_board" end
    return clue
end

function C.Validate(ids, text)
    local forms, reason = C.PrepareBoard(ids)
    if not forms then return nil, reason end
    return C.ValidatePrepared(forms, text)
end
