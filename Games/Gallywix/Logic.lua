-- Pure wheel geometry. Fields follow the exact v2 SVG artwork clockwise.
local A = _G.ArcadiaNexus
A.GWX_Logic = {}
local L = A.GWX_Logic

L.fields = {
    500, 300, 700, 400, 600, 250, "bankrupt", 500,
    800, 300, 450, 600, "extra_spin", 350, 500, 900,
    400, 650, "lose_turn", 300, 750, 500, 1000, 400,
}
-- Exact 24-way geometry: field 1 at twelve o'clock, each wedge 15 degrees.
L.segmentDegrees = 360 / #L.fields
-- House-rule tuning, independent of rendering and session timelines.
L.gallywixChance = 0.15
function L:SelectIntervention(enabled, mode, target, original, random)
    random = random or math.random
    if mode == "off" then return nil end
    if mode ~= "force" and (not enabled or random() >= self.gallywixChance) then return nil end
    if mode == "force" and self:IsValidIndex(target) then return target end
    -- Every other field is reachable, including Bankrupt, from any position.
    local offset = random(1, #self.fields - 1)
    return (original - 1 + offset) % #self.fields + 1
end
L.fieldBoundaries = {}
for index = 0, #L.fields do
    L.fieldBoundaries[index + 1] = index * L.segmentDegrees - L.segmentDegrees / 2
end
L.artOffsetDegrees = 0
L.pointerDegrees = 0

function L:IsValidIndex(index)
    return type(index) == "number" and index == math.floor(index)
        and index >= 1 and index <= #self.fields
end

function L:GetFieldDegrees(index)
    if not self:IsValidIndex(index) then return nil end
    local startAngle, endAngle = self.fieldBoundaries[index], self.fieldBoundaries[index + 1]
    return (self.artOffsetDegrees + (startAngle + endAngle) / 2) % 360
end

-- All public angles are clockwise degrees. Rendering converts to radians.
function L:GetTargetDegrees(index)
    local field = self:GetFieldDegrees(index)
    if not field then return nil end
    return (self.pointerDegrees - field) % 360
end

function L:GetSpinDistance(currentDegrees, index, turns)
    local target = self:GetTargetDegrees(index)
    if not target then return nil end
    return (turns or 5) * 360 + (target - currentDegrees) % 360
end

function L:GetIndexAtPointer(rotationDegrees)
    local localAngle = (self.pointerDegrees - rotationDegrees - self.artOffsetDegrees) % 360
    if localAngle >= self.fieldBoundaries[#self.fieldBoundaries] then localAngle = localAngle - 360 end
    for index = 1, #self.fields do
        if localAngle >= self.fieldBoundaries[index] and localAngle < self.fieldBoundaries[index + 1] then
            return index
        end
    end
end

function L:SelectIndex(selection, randomIndex)
    if selection == "random" then
        local index = (randomIndex or math.random)(1, #self.fields)
        return self:IsValidIndex(index) and index or nil
    end
    return self:IsValidIndex(selection) and selection or nil
end

function L:Ease(progress)
    local t = math.max(0, math.min(1, progress))
    return t * t * t * (t * (t * 6 - 15) + 10)
end
