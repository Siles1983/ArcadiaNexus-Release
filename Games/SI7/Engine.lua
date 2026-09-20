--[[
    Games/SI7/Engine.lua
    Hotseat lokal; MP nur über HasMultiplayer() + Match-Runtime.
]]

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.SI7_Engine = {}
local E = ArcadiaNexus.SI7_Engine

E._sessionId = nil
E.state = "IDLE"
E.mode = "hotseat"
E.public = nil
E.key = nil
E.viewSeat = 1
E.match = nil
E._resultEmitted = false

local function Logic()
    return ArcadiaNexus.SI7_Logic
end

local function Settings()
    return ArcadiaNexus.SI7_Settings
end

local function SoundOn()
    local S = Settings()
    return S and S:Get("soundEnabled")
end

local function Play(id)
    if SoundOn() then PlaySound(id) end
end

local function Notify()
    local R = ArcadiaNexus.SI7_Renderer
    local M = ArcadiaNexus.Match
    if M and M.NotifyGameView then
        M.NotifyGameView(E, "SI7", function()
            if R and R.Render then R:Render() end
        end)
        return
    end
    if R and R.Render then R:Render() end
end

local function MatchOpts(engine)
    return Logic().MatchOpts(engine)
end

local function LocalTeam(seat)
    if seat == 1 or seat == 2 then return "R" end
    if seat == 3 or seat == 4 then return "B" end
    return nil
end

function E:OnMatchPublic()
    local M = ArcadiaNexus.Match
    if M and M.HandleGamePublic then
        M.HandleGamePublic(self, function()
            if self.state == "LOBBY" then self:SyncLobbyGroups() end
        end)
    end
    Notify()
end

function E:OnMatchState(st)
    local M = ArcadiaNexus.Match
    if M and M.HandleGameState then
        M.HandleGameState(self, "SI7", st, {
            onPlaying = function()
                if self.match and self.match.seat then
                    self.viewSeat = self.match.seat
                end
            end,
        })
    end
    Notify()
end

function E:OnMatchReject(f)
    local M = ArcadiaNexus.Match
    if M and M.HandleGameReject then
        M.HandleGameReject(self, "SI7", f)
    end
    Notify()
end

function E:OnMatchResult(node, resultId)
    if self.match ~= node or not self._sessionId or node:GetState() ~= "FINISHED" then return end
    if self._resultEmitted then return end
    self._resultEmitted = true
    local pub = node and node:GetPublicState()
    local seat = node and node.seat
    local team = LocalTeam(seat)
    local won = pub and team and pub.winner == team
    local spy = (seat == 1 or seat == 3)
    local reason = pub and pub.winReason or ""
    local enemyLeft = 0
    if pub and team == "R" then
        enemyLeft = pub.blue or 0
    elseif pub and team == "B" then
        enemyLeft = pub.red or 0
    end
    local score = 0
    if won then
        score = 100 + enemyLeft * 10
        if reason == "cleared" then score = score + 50 end
    end
    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId = "SI7",
        resultId = resultId,
        matchHost = node.hostKey,
        difficulty = "normal",
        score = score,
        result = won and "WIN" or "LOSS",
        stats = {
            assassin = (won and reason == "assassin") and 1 or 0,
            cleared = (won and reason == "cleared") and 1 or 0,
            spyWin = (won and spy) and 1 or 0,
            opWin = (won and not spy) and 1 or 0,
            hordeWin = (won and team == "R") and 1 or 0,
            allianceWin = (won and team == "B") and 1 or 0,
            enemyLeft = won and enemyLeft or 0,
            clues = pub and pub.clues or 0,
            guesses = pub and pub.guesses or 0,
        },
    })
    self:MaybeShowResult()
end

function E:MaybeShowResult()
    local R = ArcadiaNexus.SI7_Renderer
    if R and R.ShowGameOver then R:ShowGameOver() end
end

function E:StartGame(config)
    config = config or {}
    local mode = config.mode or "hotseat"
    if mode == "host" or mode == "join" or mode == "rejoin" then
        local M = ArcadiaNexus.Match
        if not M or not M.BeginNetworkedGame then
            self._notice = "nomp"
            Notify()
            return
        end
        M.BeginNetworkedGame(self, "SI7", config, Notify, MatchOpts, {
            onBefore = function()
                local S = Settings()
                if S then S:Set("lastMode", mode) end
                self._selectedWordSet = config.wordSet or (S and S:Get("wordSet")) or "AZEROTH"
            end,
            onHosted = function()
                if self.match and self.match.publicState then
                    self.match.publicState.wordSet = self._selectedWordSet or "AZEROTH"
                end
                self.lobbyGroup = {}
                self:SyncLobbyGroups()
                if self.match and self.match.LobbyChanged then self.match:LobbyChanged() end
            end,
        })
        return
    end
    self.mode = mode
    self._resultEmitted = false
    self._notice = nil
    local S = Settings()
    if S then S:Set("lastMode", mode) end

    self:StopMatchQuiet()
    self._selectedWordSet = config.wordSet or (S and S:Get("wordSet")) or "AZEROTH"
    local pub, key = Logic().Deal(self._selectedWordSet)
    self.public = pub
    self.key = key
    self.viewSeat = 1
    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("SI7", E._sessionId)
    self.state = "PLAYING"
    Play(857)
    Notify()
end

function E:SetReady(ready)
    local M = ArcadiaNexus.Match
    if M and M.SetEngineReady then M.SetEngineReady(self, ready) end
    Notify()
end

function E:TryStartMatch()
    local M = ArcadiaNexus.Match
    if M and M.TryEngineStart then M.TryEngineStart(self) end
    Notify()
end

function E:SyncLobbyGroups()
    if not self.match or not self.match.isHost then return end
    self.lobbyGroup = self.lobbyGroup or {}
    local seats = self.match.seats or {}
    local present = {}
    for i = 1, 4 do
        local k = seats[i]
        if k and k ~= "" then present[k] = true end
    end
    for k in pairs(self.lobbyGroup) do
        if not present[k] then self.lobbyGroup[k] = nil end
    end
    local function count(g)
        local n = 0
        for _, v in pairs(self.lobbyGroup) do
            if v == g then n = n + 1 end
        end
        return n
    end
    for i = 1, 4 do
        local k = seats[i]
        if k and k ~= "" and not self.lobbyGroup[k] then
            local nA, nB = count("A"), count("B")
            if nB == 0 and nA > 0 then
                self.lobbyGroup[k] = "B"
            elseif nA <= nB then
                self.lobbyGroup[k] = "A"
            else
                self.lobbyGroup[k] = "B"
            end
        end
    end
    self.match.lobbyGroup = self.lobbyGroup
end

function E:SetLobbyGroup(playerKey, group)
    if not self.match or not self.match.isHost or self.state ~= "LOBBY" then return end
    if group ~= "A" and group ~= "B" then return end
    self:SyncLobbyGroups()
    if self.lobbyGroup[playerKey] == group then return end
    local swapKey
    local n = 0
    for k, v in pairs(self.lobbyGroup) do
        if v == group and k ~= playerKey then
            n = n + 1
            swapKey = k
        end
    end
    if n >= 2 and swapKey then
        local prev = self.lobbyGroup[playerKey]
        self.lobbyGroup[swapKey] = prev or (group == "A" and "B" or "A")
    end
    self.lobbyGroup[playerKey] = group
    self.match.lobbyGroup = self.lobbyGroup
    if self.match.LobbyChanged then self.match:LobbyChanged() end
    Notify()
end

function E:AssignMatchSeats(node)
    self:SyncLobbyGroups()
    local ordered = Logic().RollGameSeats(node.seats, self.lobbyGroup)
    if not ordered then
        self._notice = "groups"
        return false
    end
    node.seats = ordered
    self.viewSeat = nil
    for i = 1, 4 do
        if ordered[i] == node.playerKey then
            node.seat = i
            if not self.viewSeat then self.viewSeat = i end
        end
    end
    return true
end

function E:OwnsSeat(seat)
    if not self.match or not seat then return false end
    local P = ArcadiaNexus.MatchProtocol
    local seats = self.match.seats or {}
    if P and P.SamePlayer then
        return P.SamePlayer(seats[seat], self.match.playerKey) == true
    end
    return seats[seat] == self.match.playerKey
end

function E:SetViewSeat(seat)
    if not (seat >= 1 and seat <= 4) then return end
    if self.mode == "hotseat" then
        self.viewSeat = seat
        Notify()
        return
    end
    if self:OwnsSeat(seat) then
        self.viewSeat = seat
        Notify()
    end
end

function E:SubmitClue(word, n)
    if self.state ~= "PLAYING" then return end
    local pub = self.mode == "hotseat" and self.public or (self.match and self.match:GetPublicState())
    local _, reason = Logic().ValidateClue(pub, word)
    if reason then
        self._notice = reason
        Notify()
        return
    end
    self._notice = nil
    if self.mode == "hotseat" then
        if Logic().Apply(self.public, self.key, { kind = "CLUE", c = word, n = n }, self.viewSeat) then
            Play(857)
            self:CheckHotseatEnd()
            Notify()
        end
        return
    end
    if self.match then self.match:SendIntent("CLUE", { c = word, n = n, senderSeat = self.viewSeat or self.match.seat }) end
    Notify()
end

function E:Guess(index)
    if self.state ~= "PLAYING" then return end
    if self.mode == "hotseat" then
        if Logic().Apply(self.public, self.key, { kind = "GUESS", i = index }, self.viewSeat) then
            Play(847)
            self:CheckHotseatEnd()
            Notify()
        end
        return
    end
    if self.match then self.match:SendIntent("GUESS", { i = index, senderSeat = self.viewSeat or self.match.seat }) end
    Notify()
end

function E:Pass()
    if self.state ~= "PLAYING" then return end
    if self.mode == "hotseat" then
        if Logic().Apply(self.public, self.key, { kind = "PASS" }, self.viewSeat) then
            Play(857)
            Notify()
        end
        return
    end
    if self.match then self.match:SendIntent("PASS", { senderSeat = self.viewSeat or self.match.seat }) end
    Notify()
end

function E:CheckHotseatEnd()
    if self.mode ~= "hotseat" then return end
    if Logic().IsFinished(self.public) then
        self.state = "FINISHED"
        self:MaybeShowResult()
    end
end

function E:GetView()
    local L = Logic()
    local pub, key, seat
    local ownedSeats = {}
    if self.mode ~= "hotseat" and self.match then
        pub = self.match:GetPublicState() or L.EmptyPublic()
        key = self.match:GetPrivateState()
        local P = ArcadiaNexus.MatchProtocol
        local seats = self.match.seats or {}
        for i = 1, 4 do
            local mine = seats[i] == self.match.playerKey
            if not mine and P and P.SamePlayer then
                mine = P.SamePlayer(seats[i], self.match.playerKey)
            end
            if mine then
                ownedSeats[#ownedSeats + 1] = i
            end
        end
        seat = self.viewSeat
        if not self:OwnsSeat(seat) then
            seat = self.match.seat or ownedSeats[1]
            self.viewSeat = seat
        end
    else
        pub = self.public or L.EmptyPublic()
        seat = self.viewSeat
        key = L.PrivateForSeat(seat, self.key)
        ownedSeats = { 1, 2, 3, 4 }
    end
    local team, spy = L.Role(seat)
    if not spy or type(key) ~= "string" or #key ~= 25 then
        key = nil
    end
    local canClue = self.state == "PLAYING" and spy and team == pub.turn and pub.phase == "C"
    local canGuess = self.state == "PLAYING" and (not spy) and team == pub.turn and pub.phase == "G"
    local lobbyPlayers = {}
    if self.state == "LOBBY" and self.match then
        self:SyncLobbyGroups()
        local seats = self.match.seats or {}
        local ready = self.match.ready or {}
        local groups = self.match.lobbyGroup or self.lobbyGroup
        local seen = {}
        for i = 1, 4 do
            local k = seats[i]
            if k and k ~= "" and not seen[k] then
                seen[k] = true
                lobbyPlayers[#lobbyPlayers + 1] = {
                    key = k,
                    name = k:match("^([^-]+)") or k,
                    group = groups and groups[k] or nil,
                    ready = ready[i] and true or false,
                    self = k == self.match.playerKey,
                }
            end
        end
    end
    return {
        state = self.state,
        mode = self.mode,
        pub = pub,
        key = key,
        seat = seat,
        team = team,
        spy = spy,
        canClue = canClue,
        canGuess = canGuess,
        mp = self.mode ~= "hotseat",
        isHost = self.match and self.match.isHost,
        matchState = self.match and self.match:GetState(),
        notice = self._notice,
        lobbyPlayers = lobbyPlayers,
        ownedSeats = ownedSeats,
        duo = #ownedSeats > 1,
    }
end

function E:HideView()
    local M = ArcadiaNexus.Match
    if M and M.HideEngineView then M.HideEngineView(self) end
end

function E:StopMatchQuiet()
    local M = ArcadiaNexus.Match
    if M and M.StopEngineMatch then M.StopEngineMatch(self) end
end

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("SI7", E._sessionId)
        E._sessionId = nil
    end
    self:StopMatchQuiet()
    self.public = nil
    self.key = nil
    self.lobbyGroup = nil
    self.state = "IDLE"
    local R = ArcadiaNexus.SI7_Renderer
    if R then R:EnterIdleState() end
    Notify()
end
