--[[
    Azeroth Intelligence — SI:7
    Shared stable concept IDs from Hangman. Each client resolves the IDs in
    its own locale, so STURMWIND and STORMWIND still denote the same card.
]]

ArcadiaNexus = ArcadiaNexus or {}
local HangmanWords = ArcadiaNexus.HGM_Words

if not HangmanWords or not HangmanWords.GetIds then
    error("SI:7 requires the Hangman word catalogue to be loaded first.")
end

ArcadiaNexus.SI7_Words = HangmanWords:GetIds()
