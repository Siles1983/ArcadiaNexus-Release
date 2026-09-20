-- Visual overlay for every currently active Darkmoon Pinball table element.
local AN = _G.ArcadiaNexus
local E = AN.PinballTableEditor
if not E then return end
local WHITE = "Interface\\Buttons\\WHITE8X8"
local baseRedraw = E.redraw

local function tableDef()
    local L = AN.DMP_Logic
    return L and L.GetTable and L:GetTable(E.id)
end

local function texture(n)
    E._objectTextures = E._objectTextures or {}
    local t = E._objectTextures[n]
    if not t then t = E.canvas:CreateTexture(nil, "OVERLAY"); E._objectTextures[n] = t end
    t:Show()
    return t
end

local function line(n, ax, ay, bx, by, r, g, b, width)
    local t = texture(n)
    local x1, y1 = E:point(ax, ay)
    local x2, y2 = E:point(bx, by)
    local dx, dy = x2 - x1, y2 - y1
    t:SetTexture(WHITE)
    t:SetSize(math.max(2, math.sqrt(dx * dx + dy * dy)), width or 2)
    t:ClearAllPoints()
    t:SetPoint("CENTER", E.canvas, "TOPLEFT", (x1 + x2) * .5, -((y1 + y2) * .5))
    t:SetVertexColor(r, g, b, .9)
    if t.SetRotation then t:SetRotation(-math.atan2(dy, dx)) end
end

local function ring(n, x, y, radius, r, g, b)
    local t = texture(n)
    local px, py, s = E:point(x, y)
    local d = math.max(7, radius * 2 * s)
    local A = AN.DMP_Assets
    t:SetTexture((A and A.Get and A.Get("fx", "ring")) or WHITE)
    t:SetSize(d, d)
    t:ClearAllPoints()
    t:SetPoint("CENTER", E.canvas, "TOPLEFT", px, -py)
    t:SetVertexColor(r, g, b, .95)
end

local function rect(n, q, r, g, b)
    line(n, q.x1, q.y1, q.x2, q.y1, r, g, b)
    line(n + 1, q.x2, q.y1, q.x2, q.y2, r, g, b)
    line(n + 2, q.x2, q.y2, q.x1, q.y2, r, g, b)
    line(n + 3, q.x1, q.y2, q.x1, q.y1, r, g, b)
end

function E:redraw()
    baseRedraw(self)
    local d = tableDef()
    if not d or not self.canvas then return end
    local n = 1
    for i = 1, #(d.bumpers or {}) do local q=d.bumpers[i]; ring(n,q.x,q.y,q.r,1,.8,.1); n=n+1 end
    for i = 1, #(d.targets or {}) do local q=d.targets[i]; ring(n,q.x,q.y,q.r,.8,.25,1); n=n+1 end
    for i = 1, #(d.kickers or {}) do local q=d.kickers[i]; ring(n,q.x,q.y,q.r,1,.25,.25); n=n+1 end
    for i = 1, #(d.flippers or {}) do
        local q=d.flippers[i]; local a=q.restAngle or 0
        line(n,q.px,q.py,q.px+math.cos(a)*q.length,q.py+math.sin(a)*q.length,1,.25,.25,4); n=n+1
        ring(n,q.px,q.py,q.radius or 5,1,.25,.25); n=n+1
    end
    for i = 1, #(d.slingshots or {}) do local q=d.slingshots[i]; line(n,q.ax,q.ay,q.bx,q.by,1,.55,.1,4); n=n+1 end
    for i = 1, #(d.ramps or {}) do local q=d.ramps[i]; rect(n,q,.2,1,.75); n=n+4 end
    for i = 1, #(d.inlanes or {}) do local q=d.inlanes[i]; rect(n,q,.2,.9,1); n=n+4 end
    for i = 1, #(d.outlanes or {}) do local q=d.outlanes[i]; rect(n,q,1,.4,.4); n=n+4 end
    if d.lock then rect(n,d.lock,.9,.4,1); n=n+4 end
    if d.jackpot then rect(n,d.jackpot,1,.9,.2); n=n+4 end
    if d.drain then
        line(n,d.drain.x1,d.drain.y1,d.drain.x2,d.drain.y2 or d.drain.y1,1,.15,.15,3); n=n+1
    end
    local lane=d.launchLane or {}
    local spawn=d.spawn or {}
    local cx=lane.centerX or ((lane.x or d.shooterX or 246)+10)
    local y0,y1=spawn.y or 348,lane.yBot or 400
    line(n,cx,y0,cx,y1,.85,.85,.85,3); n=n+1
    ring(n,spawn.x or cx,spawn.y or y0,d.ballRadius or 7,1,1,1); n=n+1
    local path=d.launchGuide and d.launchGuide.points or {}
    for i=1,#path-1 do line(n,path[i].x,path[i].y,path[i+1].x,path[i+1].y,.2,1,.2,3); n=n+1 end
    for i=n,#(self._objectTextures or {}) do self._objectTextures[i]:Hide() end
end-- Builder controls: mutate the loaded table data and export a complete placement map.
local _set,_down,_up,_move,_build,_export=E.setTable,E.down,E.up,E.move,E.build,E.export
local function L() return tableDef() end
local function cp(v) if type(v)~="table" then return v end local o={} for k,x in pairs(v) do o[k]=cp(x) end return o end
local function dis(a,b,c,d) local x,y=a-c,b-d return math.sqrt(x*x+y*y) end
local function hit(x,y)
 local d=L(); if not d then return end local _,_,s=E:origin(); local best,h=20/s
 local function p(k,i,z,a,b) local q=dis(x,y,a,b); if q<best then best,h=q,{k=k,i=i,z=z} end end
 for _,k in ipairs({"bumpers","targets","kickers"}) do for i,q in ipairs(d[k] or {}) do p(k,i,"c",q.x,q.y) end end
 for i,q in ipairs(d.flippers or {}) do local a=q.restAngle or 0; p("flippers",i,"p",q.px,q.py); p("flippers",i,"t",q.px+math.cos(a)*q.length,q.py+math.sin(a)*q.length) end
 for i,q in ipairs(d.slingshots or {}) do p("slingshots",i,"a",q.ax,q.ay);p("slingshots",i,"b",q.bx,q.by) end
 for _,k in ipairs({"ramps","inlanes","outlanes"}) do for i,q in ipairs(d[k] or {}) do p(k,i,"a",q.x1,q.y1);p(k,i,"b",q.x2,q.y2) end end
 for _,k in ipairs({"lock","jackpot"}) do local q=d[k];if q then p(k,1,"a",q.x1,q.y1);p(k,1,"b",q.x2,q.y2) end end
 if d.drain then p("drain",1,"a",d.drain.x1,d.drain.y1);p("drain",1,"b",d.drain.x2,d.drain.y2 or d.drain.y1) end
 if d.spawn then p("spawn",1,"c",d.spawn.x,d.spawn.y) end
 if d.launchLane then p("spring",1,"c",d.launchLane.centerX or d.launchLane.x,d.launchLane.yBot or 400) end
 for i,q in ipairs(d.launchGuide and d.launchGuide.points or {}) do p("guide",i,"c",q.x,q.y) end
 return h
end
local function add(k,x,y)
 local d=L();if not d then return end
 if k=="bumper" then d.bumpers[#d.bumpers+1]={id="bumper_dev_"..(#d.bumpers+1),x=x,y=y,r=12,score=75,kick=220}
 elseif k=="target" then d.targets[#d.targets+1]={id="target_dev_"..(#d.targets+1),x=x,y=y,r=8,order=#d.targets+1}
 elseif k=="kicker" then d.kickers[#d.kickers+1]={id="kicker_dev_"..(#d.kickers+1),x=x,y=y,r=22,kick=320}
 elseif k=="flipper" then local l=x<140;d.flippers[#d.flippers+1]={id=l and "left_dev" or "right_dev",px=x,py=y,length=46,radius=5,restAngle=l and .52 or math.pi-.52,activeAngle=l and -.58 or math.pi+.58,swingSpeed=18,returnSpeed=14,restitution=.35}
 elseif k=="sling" then d.slingshots[#d.slingshots+1]={id="sling_dev_"..(#d.slingshots+1),ax=x-18,ay=y-18,bx=x+18,by=y+18,kick=180}
 elseif k=="ramp" or k=="inlane" or k=="outlane" then local n=k=="ramp" and "ramps" or k=="inlane" and "inlanes" or "outlanes";d[n][#d[n]+1]={id=n.."_dev_"..(#d[n]+1),side=x<140 and "left" or "right",x1=x-16,y1=y-16,x2=x+16,y2=y+16}
 elseif k=="lock" or k=="jackpot" then d[k]={id=k.."_dev",x1=x-16,y1=y-12,x2=x+16,y2=y+12}
 elseif k=="drain" then d.drain={points={{x=x-28,y=y-5},{x=x+28,y=y-5},{x=x+28,y=y+5},{x=x-28,y=y+5}}}
 elseif k=="ball" then d.spawn={x=x,y=y}
 elseif k=="spring" then d.launchLane=d.launchLane or {};d.launchLane.x,d.launchLane.centerX,d.launchLane.yBot=x,x,y;d.spawn={x=x,y=y-48}
 elseif k=="guide" then d.launchGuide=d.launchGuide or {points={}};d.launchGuide.points[#d.launchGuide.points+1]={x=x,y=y} end
end
local function shift(h,x,y)
 local d=L();local q=(h.k=="lock" or h.k=="jackpot" or h.k=="drain") and d[h.k] or (d[h.k] and d[h.k][h.i])
 if not q then return end
 if h.k=="bumpers" or h.k=="targets" or h.k=="kickers" then if h.r then q.r=math.max(2,dis(x,y,q.x,q.y)) else q.x,q.y=x,y end
 elseif h.k=="flippers" then if h.z=="p" then q.px,q.py=x,y else q.length=math.max(8,dis(x,y,q.px,q.py));q.restAngle=math.atan2(y-q.py,x-q.px) end
 elseif h.k=="slingshots" then if h.z=="a" then q.ax,q.ay=x,y else q.bx,q.by=x,y end
 elseif h.k=="ramps" or h.k=="inlanes" or h.k=="outlanes" then if h.z=="a" then q.x1,q.y1=x,y else q.x2,q.y2=x,y end
 elseif h.k=="lock" or h.k=="jackpot" then if h.z=="a" then q.x1,q.y1=x,y else q.x2,q.y2=x,y end
 elseif h.k=="drain" then if h.z=="a" then q.x1,q.y1=x,y else q.x2,q.y2=x,y end
 elseif h.k=="spawn" then d.spawn.x,d.spawn.y=x,y
 elseif h.k=="spring" then d.launchLane.x,d.launchLane.centerX,d.launchLane.yBot=x,x,y
 elseif h.k=="guide" then q.x,q.y=x,y end
end
local function del(h) local d=L();if h.k=="lock" or h.k=="jackpot" or h.k=="drain" or h.k=="spawn" then d[h.k]=nil elseif h.k=="spring" then d.launchLane=nil elseif h.k=="guide" then table.remove(d.launchGuide.points,h.i) else table.remove(d[h.k],h.i) end end
function E:setTable(id) _set(self,id);self._tableOriginal=cp(L()) end
function E:down() local x,y=self:world();if not x then return end;local make={bumper=1,target=1,kicker=1,flipper=1,sling=1,ramp=1,inlane=1,outlane=1,lock=1,jackpot=1,drain=1,ball=1,spring=1,guide=1};if make[self.tool] then add(self.tool,x,y);self:redraw();return end;local h=hit(x,y);if self.tool=="delete" and h then del(h);self:redraw();return end;if self.tool=="move" and h then h.r=IsShiftKeyDown() and (h.k=="bumpers" or h.k=="targets" or h.k=="kickers");self.objectDrag=h;return end;_down(self) end
function E:move() if self.objectDrag then local x,y=self:world();if x then shift(self.objectDrag,x,y);self:redraw() end;return end;_move(self) end
function E:up() if self.objectDrag then self.objectDrag=nil;self:redraw();return end;_up(self) end
local function n(v)return string.format("%.3f",v):gsub("0+$",""):gsub("%.$","")end
local function dump(v,i) i=i or 0;if type(v)=="number"then return n(v)elseif type(v)=="boolean"then return tostring(v)elseif type(v)=="string"then return string.format("%q",v)elseif type(v)~="table"then return"nil"end;local p,np=string.rep(" ",i),string.rep(" ",i+4);local a=true;local ks={};for k in pairs(v)do ks[#ks+1]=k;if type(k)~="number"then a=false end end;if not a then table.sort(ks,function(x,y)return tostring(x)<tostring(y)end)end;local o={"{"};if a then for j=1,#v do o[#o+1]=np..dump(v[j],i+4)..","end else for _,k in ipairs(ks)do o[#o+1]=np..k.." = "..dump(v[k],i+4)..","end end;o[#o+1]=p.."}";return table.concat(o,"\n")end
function E:export() _export(self);local d=L();local map={launchLane=d.launchLane,launchGuide=d.launchGuide,spawn=d.spawn,drain=d.drain,walls=self.draft.walls,posts=self.draft.posts,outlanes=d.outlanes,inlanes=d.inlanes,slingshots=d.slingshots,kickers=d.kickers,bumpers=d.bumpers,ramps=d.ramps,targets=d.targets,lock=d.lock,jackpot=d.jackpot,flippers=d.flippers};local o={"-- Pinball Table Editor: "..self.id,"-- Paste these blocks into the table definition."};for k,v in pairs(map)do if v then o[#o+1]=k.." = "..dump(v)..","end end;self.output.edit:SetText(table.concat(o,"\n\n"));self.output.edit:SetFocus();self.output.edit:HighlightText()end
function E:build() _build(self);if self._builder then return end;self._builder=true;local h=CreateFrame("Frame",nil,self.frame);h:SetPoint("TOPLEFT",10,-308);h:SetSize(145,260);local t={{"Bumper","bumper"},{"Target","target"},{"Kicker","kicker"},{"Flipper","flipper"},{"Slingshot","sling"},{"Ramp","ramp"},{"Inlane","inlane"},{"Outlane","outlane"},{"Lock","lock"},{"Jackpot","jackpot"},{"Drain","drain"},{"Ball","ball"},{"Spring","spring"},{"Guide","guide"},{"Reset live","reset"}};for i,e in ipairs(t)do local b=AN.UI.CreateArcadiaButton(h,e[1],68,22);b:SetPoint("TOPLEFT",((i-1)%2)*74,-math.floor((i-1)/2)*26);b:SetScript("OnClick",function()if e[2]=="reset"then local d=L();for k in pairs(d)do d[k]=nil end;for k,v in pairs(cp(E._tableOriginal))do d[k]=v end;E:setTable(E.id)else E.tool=e[2]end end)end;self.view:HookScript("OnUpdate",function()if self.objectDrag then self:move()end end)end
-- Usability layer: selection, descriptions, independent export close and flipper variants.
local builderDown,builderRedraw,builderExport=E.down,E.redraw,E.export
local function selectedBox(h)
 local d=L();if not h or not d then return end
 local q=(h.k=="lock" or h.k=="jackpot" or h.k=="drain") and d[h.k] or (d[h.k] and d[h.k][h.i])
 if not q then return end
 if h.k=="bumpers" or h.k=="targets" or h.k=="kickers" then return q.x-q.r-4,q.y-q.r-4,q.x+q.r+4,q.y+q.r+4 end
 if h.k=="flippers" then local a=q.restAngle or 0;local x=q.px+math.cos(a)*q.length;local y=q.py+math.sin(a)*q.length;return math.min(q.px,x)-6,math.min(q.py,y)-6,math.max(q.px,x)+6,math.max(q.py,y)+6 end
 if h.k=="slingshots" then return math.min(q.ax,q.bx)-5,math.min(q.ay,q.by)-5,math.max(q.ax,q.bx)+5,math.max(q.ay,q.by)+5 end
 if h.k=="ramps" or h.k=="inlanes" or h.k=="outlanes" or h.k=="lock" or h.k=="jackpot" then return math.min(q.x1,q.x2)-4,math.min(q.y1,q.y2)-4,math.max(q.x1,q.x2)+4,math.max(q.y1,q.y2)+4 end
 if h.k=="drain" then return math.min(q.x1,q.x2)-5,math.min(q.y1,q.y2)-5,math.max(q.x1,q.x2)+5,math.max(q.y1,q.y2)+5 end
 if h.k=="spawn" then return q.x-12,q.y-12,q.x+12,q.y+12 end
 if h.k=="spring" then local x=q.centerX or q.x;return x-10,(q.yBot or 400)-60,x+10,(q.yBot or 400)+5 end
 if h.k=="guide" then return q.x-10,q.y-10,q.x+10,q.y+10 end
end
function E:redraw()
 builderRedraw(self)
 local a,b,c,d=selectedBox(self.selected)
 if not a then return end
 self._selectLines=self._selectLines or {}
 local function edge(i,x1,y1,x2,y2)
  local t=self._selectLines[i] or self.canvas:CreateTexture(nil,"HIGHLIGHT");self._selectLines[i]=t
  local px,py=self:point(x1,y1);local qx,qy=self:point(x2,y2);local dx,dy=qx-px,qy-py
  t:SetTexture(WHITE);t:SetVertexColor(.25,1,.35,1);t:SetSize(math.max(2,math.sqrt(dx*dx+dy*dy)),2);t:ClearAllPoints();t:SetPoint("CENTER",self.canvas,"TOPLEFT",(px+qx)*.5,-((py+qy)*.5));if t.SetRotation then t:SetRotation(-math.atan2(dy,dx)) end;t:Show()
 end
 edge(1,a,b,c,b);edge(2,c,b,c,d);edge(3,c,d,a,d);edge(4,a,d,a,b)
end
function E:down()
 local x,y=self:world()
 if self.tool=="flipper_left" or self.tool=="flipper_right" then
  local d=L();if d and x then local left=self.tool=="flipper_left";d.flippers[#d.flippers+1]={id=left and "left_dev" or "right_dev",px=x,py=y,length=46,radius=5,restAngle=left and .52 or math.pi-.52,activeAngle=left and -.58 or math.pi+.58,swingSpeed=18,returnSpeed=14,restitution=.35};self.selected={k="flippers",i=#d.flippers,z="p"};self:redraw() end;return
 end
 builderDown(self)
 if self.tool=="move" and x then self.selected=hit(x,y);self:redraw() end
end
function E:resetTable()
 -- The user-facing reset intentionally returns to the currently loaded live definition.
 local S=AN.DevStore;if S and S.Get then local db=S.Get();if db.pinballEditor then db.pinballEditor[E.id]=nil end end
 _set(E,E.id);E._tableOriginal=cp(L());E.selected=nil;E:redraw()
end
function E:export()
 builderExport(self)
 local f=self.output
 if not f._closeButton then
  local b=AN.UI.CreateArcadiaButton(f,"X",26,26);b:SetPoint("TOPRIGHT",-8,-8);b:SetScript("OnClick",function() f:Hide() end);f._closeButton=b
 end
end
local function tooltip(button,title,body)
 button:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(title,1,.82,.15);GameTooltip:AddLine(body,1,1,1,true);GameTooltip:Show() end)
 button:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
local oldBuild=E.build
function E:build()
 oldBuild(self)
 if self._usability then return end
 self._usability=true
 local h=CreateFrame("Frame",nil,self.frame);h:SetPoint("TOPLEFT",10,-516);h:SetSize(145,138)
 local note=self.frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");note:SetPoint("BOTTOMLEFT",12,36);note:SetWidth(860);note:SetJustifyH("LEFT");note:SetText("|cffffd700Legende:|r Cyan = Wände/Rampen/Inlanes, Orange = Posts/Slingshots, Gelb = Bumper/Jackpot, Lila = Ziele/Lock, Rot = Kicker/Flipper/Drain, Grün = Launch-Guide, Weiß/Grau = Kugel/Feder.  |cff55ff55Grüner Rahmen = Auswahl.|r")
 local defs={{"Left flip","flipper_left","Setzt einen linken Flipper."},{"Right flip","flipper_right","Setzt einen rechten, gespiegelten Flipper."},{"Angle -","angle_minus","Editor: dreht den ausgewählten Flipper um 5 Grad gegen den Uhrzeigersinn; Ruhe- und Aktivwinkel bleiben synchron."},{"Angle +","angle_plus","Editor: dreht den ausgewählten Flipper um 5 Grad im Uhrzeigersinn; Ruhe- und Aktivwinkel bleiben synchron."}}
 for i,e in ipairs(defs)do local b=AN.UI.CreateArcadiaButton(h,e[1],68,22);b:SetPoint("TOPLEFT",((i-1)%2)*74,-math.floor((i-1)/2)*26);tooltip(b,e[1],e[3]);b:SetScript("OnClick",function()
  if e[2]=="flipper_left" or e[2]=="flipper_right" then E.tool=e[2];return end
  local s=E.selected;if not s or s.k~="flippers" then return end;local q=L().flippers[s.i];local delta=e[2]=="angle_minus" and -math.rad(5) or math.rad(5);q.restAngle=q.restAngle+delta;q.activeAngle=q.activeAngle+delta;E:redraw()
 end)end
 -- Tooltips for every builder control, including the pre-existing common tools.
 local tips={Move="Vorhandenes Element anklicken und ziehen. Shift auf Kreis-Elementen ändert den Radius.",["Draw wall"]="Zwei Punkte ziehen, um eine Kollisionswand zu setzen.",["Add post"]="Physik: runder, fester Kollisionsposten. Er lenkt die Kugel ab, gibt aber weder Punkte noch Missionsfortschritt.",Delete="Klick auf ein Element entfernt es.",Bumper="Punkte + Impuls: ein Treffer stößt die Kugel ab und gibt den im Tisch gesetzten Score. Sind alle Bumper einmal getroffen, wird Ball Save aktiviert und die Bumper-Mission gestartet bzw. fortgesetzt.",Target="120 Punkte je Treffer (Standard) und Ziel wird beleuchtet. Alle Ziele beleuchtet starten Target Hunt; während der Mission zählt nur die vorgegebene Reihenfolge.",Kicker="Physik: runder Kicker, der die Kugel mit seinem kick-Wert abstößt. Aktuell weder Punkte noch Missionsfortschritt.",Slingshot="Setzt einen Slingshot; Endpunkte sind verschiebbar.",Ramp="Sensorzone: 150 Punkte je Durchfahrt (Standard). Linke und rechte Rampe starten Ramp Run; während der Mission zählen weitere Rampentreffer.",Inlane="Sicherheitszone: aktiviert den Kickback der jeweiligen Seite für die konfigurierte Dauer. Kein direkter Score.",Outlane="Gefahrenzone: ohne aktiven Kickback, Ball Save oder Shield geht die Kugel verloren. Mit Schutz wird sie zurück ins Feld geschossen.",Lock="200 Punkte je Treffer (Standard). Startet bzw. füllt Arcane Lock; nach dem Missionsziel wird als Belohnung Multiball ausgelöst.",Jackpot="Nur im Multiball aktiv: 2.500 Punkte je Treffer (Standard), jeder dritte Treffer wird zum Super-Jackpot mit 10.000 Punkten.",Drain="Vierpunkt-Drain: Mit Move die vier Ecken formen. Die drei sichtbaren Kanten 1–2, 2–3 und 3–4 lösen den Kugelverlust aus; die offene Seite 4–1 bleibt frei.",Ball="Startposition der gesperrten Kugel vor dem Abschuss. Keine Kollisions- oder Punktezone.",Spring="Setzt Startbahn, Federbasis und Spawn.",Guide="Fügt einen Launch-Guide-Stützpunkt hinzu."}
 local function scan(frame) for _,child in ipairs({frame:GetChildren()})do if child.GetText then local text=child:GetText();if tips[text] then tooltip(child,text,tips[text]) end end;scan(child) end end
 scan(self.frame)
end
-- Final toolbar cleanup: replace the generic flipper slot and bind help directly.
local function help(button,title,body)
 if not button or button._pinballHelp then return end
 button._pinballHelp=true
 button:HookScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(title,1,.82,.15);GameTooltip:AddLine(body,1,1,1,true);GameTooltip:Show() end)
 button:HookScript("OnLeave",function() GameTooltip:Hide() end)
end
local function walk(frame,fn)
 for _,child in ipairs({frame:GetChildren()}) do fn(child);walk(child,fn) end
end
local finalBuild=E.build
function E:build()
 finalBuild(self)
 if self._toolbarClean then return end
 self._toolbarClean=true
 local baseHelp={Midway="Lädt den Midway-Tisch.",Carousel="Lädt den Carousel-Tisch.",Move="Editorwerkzeug: vorhandene Elemente verschieben. Shift+Ziehen auf Bumper, Target oder Kicker verändert deren Radius.",["Draw wall"]="Physik: eine feste Begrenzung. Die Kugel prallt daran mit der Tisch-Restitution ab; sie gibt keine Punkte.",["Add post"]="Physik: runder, fester Kollisionsposten. Er lenkt die Kugel ab, gibt aber weder Punkte noch Missionsfortschritt.",Delete="Klick auf ein Element entfernt es.",["Reset table"]="Lädt Wände und Posts vom aktuellen Live-Tisch neu.",["Export Lua"]="Erzeugt einen kopierbaren Lua-Block aller Tischobjekte.",Bumper="Punkte + Impuls: ein Treffer stößt die Kugel ab und gibt den im Tisch gesetzten Score. Sind alle Bumper einmal getroffen, wird Ball Save aktiviert und die Bumper-Mission gestartet bzw. fortgesetzt.",Target="120 Punkte je Treffer (Standard) und Ziel wird beleuchtet. Alle Ziele beleuchtet starten Target Hunt; während der Mission zählt nur die vorgegebene Reihenfolge.",Kicker="Physik: runder Kicker, der die Kugel mit seinem kick-Wert abstößt. Aktuell weder Punkte noch Missionsfortschritt.",Slingshot="Physik: schräge Pralllinie. Beim Treffer gibt sie der Kugel einen zusätzlichen Impuls; aktuell keine Punkte und keine Mission.",Ramp="Sensorzone: 150 Punkte je Durchfahrt (Standard). Linke und rechte Rampe starten Ramp Run; während der Mission zählen weitere Rampentreffer.",Inlane="Sicherheitszone: aktiviert den Kickback der jeweiligen Seite für die konfigurierte Dauer. Kein direkter Score.",Outlane="Gefahrenzone: ohne aktiven Kickback, Ball Save oder Shield geht die Kugel verloren. Mit Schutz wird sie zurück ins Feld geschossen.",Lock="200 Punkte je Treffer (Standard). Startet bzw. füllt Arcane Lock; nach dem Missionsziel wird als Belohnung Multiball ausgelöst.",Jackpot="Nur im Multiball aktiv: 2.500 Punkte je Treffer (Standard), jeder dritte Treffer wird zum Super-Jackpot mit 10.000 Punkten.",Drain="Vierpunkt-Drain: Mit Move die vier Ecken formen. Die drei sichtbaren Kanten 1–2, 2–3 und 3–4 lösen den Kugelverlust aus; die offene Seite 4–1 bleibt frei.",Ball="Startposition der gesperrten Kugel vor dem Abschuss. Keine Kollisions- oder Punktezone.",Spring="Definiert Startbahn, Federbasis und Spawn. Die Plunger-Stärke bestimmt die Abschussgeschwindigkeit; keine Punktezone.",Guide="Definiert die automatische Launch-Kurve nach dem Plunger. Die Kugel folgt den Punkten bis zum Auslass; keine Punktezone.",["Reset live"]="Setzt die Live-Objekte auf den beim Öffnen geladenen Tisch zurück."}
 walk(self.frame,function(b)
  local text=b.text and b.text:GetText() or (b.GetText and b:GetText())
  if not text then return end
  if text=="Flipper" then b:Hide() end
  if baseHelp[text] then help(b,text,baseHelp[text]) end
  if text=="Left flip" then b:ClearAllPoints();b:SetPoint("TOPLEFT",self.frame,"TOPLEFT",10,-516);help(b,"Left flipper","Aktiver linker Flipper: linke Eingabe bewegt ihn und schlägt die Kugel physikalisch zurück. Keine direkten Punkte.") end
  if text=="Right flip" then b:ClearAllPoints();b:SetPoint("TOPLEFT",self.frame,"TOPLEFT",84,-516);help(b,"Right flipper","Aktiver rechter Flipper: rechte Eingabe bewegt ihn und schlägt die Kugel physikalisch zurück. Keine direkten Punkte.") end
 end)
end
-- View-only zoom: all edits and exports remain in the original 280x440 table coordinates.
local fitScale=E.scale
function E:scale() return fitScale(self)*(self.zoom or 1) end
local zoomBuild=E.build
function E:build()
 zoomBuild(self)
 if self._zoomReady then return end
 self._zoomReady=true
 self.zoom=1
 self.view:EnableMouseWheel(true)
 self.view:HookScript("OnMouseWheel",function(_,delta)
  local factor=delta>0 and 1.15 or (1/1.15)
  E.zoom=math.max(.65,math.min(3.5,(E.zoom or 1)*factor))
  E:redraw()
 end)
end
-- Keep the playfield artwork on the exact same transform as the editor overlay.
function E:layoutPlayfield()
 if not self.bg or not self.canvas then return end
 local ox,oy,s=self:origin()
 self.bg:ClearAllPoints();self.bg:SetSize(280*s,440*s);self.bg:SetPoint("TOPLEFT",self.canvas,"TOPLEFT",ox,-oy)
end
local zoomSetTable=E.setTable
function E:setTable(id) zoomSetTable(self,id);self.selected=nil;self.objectDrag=nil;self:layoutPlayfield() end
local artworkZoomBuild=E.build
function E:build()
 artworkZoomBuild(self)
 if self._artworkZoomReady then return end
 self._artworkZoomReady=true
 self.view:HookScript("OnMouseWheel",function() E:layoutPlayfield();E:redraw() end)
end
-- Middle-mouse panning for zoomed table views; it changes only the viewport transform.
local centeredOrigin=E.origin
function E:origin()
 local x,y,s=centeredOrigin(self)
 return x+(self.panX or 0),y+(self.panY or 0),s
end
local panBuild=E.build
function E:build()
 panBuild(self)
 if self._panReady then return end
 self._panReady=true
 self.panX,self.panY=0,0
 self.view:HookScript("OnMouseDown",function(_,button)
  if button~="MiddleButton" then return end
  local scale=self.view:GetEffectiveScale();local x,y=GetCursorPosition()
  self._panDrag={x=x/scale,y=y/scale,panX=self.panX,panY=self.panY}
 end)
 self.view:HookScript("OnMouseUp",function(_,button) if button=="MiddleButton" then self._panDrag=nil end end)
 self.view:HookScript("OnUpdate",function()
  local drag=self._panDrag
  if not drag then return end
  local scale=self.view:GetEffectiveScale();local x,y=GetCursorPosition()
  self.panX=drag.panX+(x/scale-drag.x);self.panY=drag.panY-(y/scale-drag.y)
  self:layoutPlayfield();self:redraw()
 end)
end
-- Live-sprite preview: artwork follows the same coordinates as the renderer, below editable geometry.
local redrawWithSelection=E.redraw
local function previewTexture(n)
 E._previewSprites=E._previewSprites or {}
 local t=E._previewSprites[n]
 if not t then t=E.canvas:CreateTexture(nil,"ARTWORK");E._previewSprites[n]=t end
 t:Show();return t
end
local function previewSprite(n,kind,state,x,y,w,h,rotation,alpha)
 local A=AN.DMP_Assets;local path=A and A.Get and A.Get(kind,state)
 if not path then return n end
 local t=previewTexture(n);local px,py,s=E:point(x,y)
 t:SetTexture(path);t:SetSize(w*s,h*s);t:ClearAllPoints();t:SetPoint("CENTER",E.canvas,"TOPLEFT",px,-py);t:SetAlpha(alpha or 1)
 if t.SetRotation then t:SetRotation(rotation or 0) end
 return n+1
end
function E:drawLivePreview()
 local d=L();if not d or not self.canvas then return end
 local n=1
 for _,q in ipairs(d.slingshots or {}) do n=previewSprite(n,"slingshot","base",(q.ax+q.bx)*.5,(q.ay+q.by)*.5,48,48,-math.atan2(q.by-q.ay,q.bx-q.ax),.95) end
 for _,q in ipairs(d.posts or {}) do n=previewSprite(n,"post","base",q.x,q.y,q.r*3,q.r*3,0,1) end
 for _,q in ipairs(d.bumpers or {}) do n=previewSprite(n,"bumper","idle",q.x,q.y,q.r*2.15,q.r*2.15,0,1) end
 for _,q in ipairs(d.targets or {}) do n=previewSprite(n,"target","idle",q.x,q.y,q.r*3,q.r*3,0,1) end
 for _,q in ipairs(d.inlanes or {}) do n=previewSprite(n,"lane","off",(q.x1+q.x2)*.5,(q.y1+q.y2)*.5,q.x2-q.x1,12,0,.9) end
 for _,q in ipairs(d.outlanes or {}) do n=previewSprite(n,"kickback","idle",(q.x1+q.x2)*.5,q.y1+8,22,22,0,.95) end
 if d.lock then n=previewSprite(n,"light","off",(d.lock.x1+d.lock.x2)*.5,(d.lock.y1+d.lock.y2)*.5,16,16,0,1) end
 if d.jackpot then n=previewSprite(n,"light","off",(d.jackpot.x1+d.jackpot.x2)*.5,(d.jackpot.y1+d.jackpot.y2)*.5,18,18,0,1) end
 for _,q in ipairs(d.flippers or {}) do local a=q.restAngle or 0;local right=q.id=="right" or string.find(q.id or "", "^right") ~= nil;n=previewSprite(n,"flipper",right and "base_right" or "base",q.px+math.cos(a)*q.length*.5,q.py+math.sin(a)*q.length*.5,q.length+14,q.radius*5,-a+(right and math.pi or 0),1) end
 local lane=d.launchLane or {};local lx=lane.centerX or lane.x or d.shooterX or 246;local ball=d.spawn or {x=lx,y=348};local r=d.ballRadius or 7;local top=ball.y+r+1;local bottom=(lane.yBot or 400)-3;local height=math.max(10,bottom-top)
 n=previewSprite(n,"plunger","spring",lx,top+height*.5,10,height,0,1);n=previewSprite(n,"plunger","knob",lx,bottom-3,14,8,0,1);n=previewSprite(n,"ball","base",ball.x,ball.y,r*2.4,r*2.4,0,.55)
 for i=n,#(E._previewSprites or {}) do E._previewSprites[i]:Hide() end
end
function E:redraw() self:drawLivePreview();redrawWithSelection(self) end
-- Posts are live physics objects as well as sprites: edit the same list shown in the preview.
local previewSetTable=E.setTable
function E:setTable(id)
 previewSetTable(self,id)
 local d=L()
 if d and self.draft then
  self.draft.posts=d.posts or {}
  self.draft.postNo=#self.draft.posts+1
 end
end
-- Table validation: checks gameplay dependencies, not only whether a visual marker exists.
local checkBuild=E.build
local function mission(def,id)
 for _,m in ipairs(def.missionDefinitions or {}) do if m.id==id then return m end end
end
local function sided(list,side)
 for _,q in ipairs(list or {}) do if q.side==side then return true end end
 return false
end
local function controlledFlipper(def,side)
 for _,q in ipairs(def.flippers or {}) do
  if q.control==side or q.side==side or string.find(q.id or "", "^"..side) then return true end
 end
 return false
end
function E:tableChecks()
 local d=L() or {};local checks={}
 local function add(ok,title,detail) checks[#checks+1]={ok=ok,title=title,detail=detail} end
 add(d.spawn and d.launchLane and d.launchGuide and #(d.launchGuide.points or {})>=2,"Launch","Spawn, Startbahn und mindestens zwei Guide-Punkte")
 add(d.drain and d.drain.x1 and d.drain.x2,"Drain","Drain-Zone vorhanden")
 add(#(d.walls or {})>=3,"Spielfeldbegrenzung","Mindestens drei Wände als äußere Sicherung")
 add(controlledFlipper(d,"left") and controlledFlipper(d,"right"),"Flipper","Mindestens ein steuerbarer linker und rechter Flipper")
 local bm=mission(d,"bumper_overdrive")
 add(#(d.bumpers or {})>0 and d.bumperBank and bm,"Bumper Overdrive","Bumper-Bank und Mission vorhanden")
 local rm=mission(d,"ramp_run")
 add(sided(d.ramps,"left") and sided(d.ramps,"right") and d.rampModule and rm,"Ramp Run","Linke + rechte Rampe und Missionsdefinition")
 local tm=mission(d,"target_hunt");local ordered=true
 for i,q in ipairs(d.targets or {}) do if q.order~=i then ordered=false end end
 add(#(d.targets or {})>=3 and ordered and d.targetBank and tm,"Target Hunt","Mindestens drei Targets in Reihenfolge 1..n")
 local lm=mission(d,"arcane_lock")
 add(d.lock and d.lockModule and lm and lm.reward=="multiball","Arcane Lock","Lock-Zone mit Multiball-Mission")
 local mb=d.multiballDefinitions or {};local balls=mb.balls or 0
 add(balls>=3 and #(d.mbSpawns or {})>=balls,"3-Ball Multiball","Drei Ball-Spawns und Multiball-Konfiguration")
 add(d.jackpot and mb.jackpotEvery and d.jackpotScore and d.superJackpotScore,"Jackpot","Jackpot-Zone, Intervall und beide Punktwerte")
 add(sided(d.inlanes,"left") and sided(d.inlanes,"right") and sided(d.outlanes,"left") and sided(d.outlanes,"right") and d.kickbacks,"Kickback","Beide In-/Outlanes plus Rückstoßwerte")
 local ids,unique={},true
 for _,key in ipairs({"bumpers","targets","kickers","posts","slingshots","ramps","inlanes","outlanes","flippers"}) do for _,q in ipairs(d[key] or {}) do if q.id then if ids[q.id] then unique=false else ids[q.id]=true end end end end
 add(unique,"Eindeutige IDs","Keine doppelten IDs zwischen Spielfeldelementen")
 return checks
end
function E:showTableChecks()
 if not self.checkFrame then
  local f=CreateFrame("Frame","ArcadiaNexus_PinballTableCheck",self.frame,"BackdropTemplate");f:SetSize(580,550);f:SetPoint("CENTER");f:SetFrameStrata("FULLSCREEN_DIALOG");f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
  local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");title:SetPoint("TOPLEFT",18,-16);title:SetText("|cffffd700Pinball Table Check|r")
  local close=AN.UI.CreateArcadiaButton(f,"X",26,26);close:SetPoint("TOPRIGHT",-10,-10);close:SetScript("OnClick",function()f:Hide()end)
  f.summary=f:CreateFontString(nil,"OVERLAY","GameFontHighlight");f.summary:SetPoint("TOPLEFT",18,-48);f.summary:SetWidth(520);f.summary:SetJustifyH("LEFT")
  f.lines={};for i=1,16 do local line=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");line:SetPoint("TOPLEFT",18,-72-(i-1)*28);line:SetWidth(520);line:SetJustifyH("LEFT");f.lines[i]=line end
  self.checkFrame=f
 end
 local f=self.checkFrame;local checks=self:tableChecks();local good=0
 for i,q in ipairs(checks) do local color=q.ok and "|cff55ff55" or "|cffff5555";f.lines[i]:SetText(color..(q.ok and "[OK] " or "[FEHLT] ")..q.title.."|r  |cffaaaaaa"..q.detail.."|r");if q.ok then good=good+1 end end
 for i=#checks+1,#f.lines do f.lines[i]:SetText("") end
 f.summary:SetText((good==#checks and "|cff55ff55Tisch vollständig: alle Gameplay-Systeme sind konfiguriert.|r" or "|cffff5555Tisch unvollständig: rote Punkte vor dem Live-Test ergänzen.|r").."  |cffaaaaaa("..good.."/"..#checks..")|r")
 f:Show()
end
function E:build()
 checkBuild(self)
 if self._checkButton then return end
 self._checkButton=AN.UI.CreateArcadiaButton(self.frame,"Check table",145,24);self._checkButton:SetPoint("TOPLEFT",10,-574);self._checkButton:SetScript("OnClick",function()self:showTableChecks()end)
 if self._checkButton.HookScript then self._checkButton:HookScript("OnEnter",function(b)GameTooltip:SetOwner(b,"ANCHOR_RIGHT");GameTooltip:SetText("Table Check",1,.82,.15);GameTooltip:AddLine("Prüft Voraussetzungen für Spielbarkeit, Missionen, 3-Ball-Multiball und Jackpot.",1,1,1,true);GameTooltip:Show()end);self._checkButton:HookScript("OnLeave",function()GameTooltip:Hide()end)end
end
-- Additional geometry checks catch common table-authoring mistakes before a live test.
local baseTableChecks=E.tableChecks
function E:tableChecks()
 local checks=baseTableChecks(self);local d=L() or {};local w,h=d.width or 280,d.height or 440
 local function add(ok,title,detail) checks[#checks+1]={ok=ok,title=title,detail=detail} end
 local drain=d.drain;local dx,dy=0,0
 if drain then dx,dy=(drain.x2 or drain.x1)-drain.x1,(drain.y2 or drain.y1)-drain.y1 end
 add(drain and (dx*dx+dy*dy)>=32*32 and math.max(drain.y1,drain.y2 or drain.y1)>=h-40,"Drain-Abdeckung","Mindestens 32 Einheiten lang und im unteren 40er-Bereich")
 local inside=true
 local function point(x,y) if not x or not y or x<0 or x>w or y<0 or y>h then inside=false end end
 for _,key in ipairs({"bumpers","targets","kickers","posts"}) do for _,q in ipairs(d[key] or {}) do point(q.x,q.y) end end
 for _,key in ipairs({"ramps","inlanes","outlanes"}) do for _,q in ipairs(d[key] or {}) do point(q.x1,q.y1);point(q.x2,q.y2) end end
 for _,key in ipairs({"lock","jackpot"}) do local q=d[key];if q then point(q.x1,q.y1);point(q.x2,q.y2) end end
 for _,q in ipairs(d.walls or {}) do point(q.ax,q.ay);point(q.bx,q.by) end
 add(inside,"Innerhalb des Felds","Wände, Sensoren und Kreisobjekte liegen innerhalb 0.."..w.." / 0.."..h)
 local circles,clear={},true
 for _,key in ipairs({"bumpers","targets","kickers","posts"}) do for _,q in ipairs(d[key] or {}) do circles[#circles+1]=q end end
 for i=1,#circles do for j=i+1,#circles do local a,b=circles[i],circles[j];local x,y=a.x-b.x,a.y-b.y;if x*x+y*y<(a.r+b.r)^2 then clear=false end end end
 add(clear,"Keine Kreisüberlappung","Bumper, Targets, Kicker und Posts überlappen sich nicht")
 local flippersOk=true
 for _,q in ipairs(d.flippers or {}) do if not q.px or not q.py or not q.length or q.length<20 or q.px<0 or q.px>w or q.py<0 or q.py>h then flippersOk=false end end
 add(flippersOk,"Flipper-Geometrie","Drehpunkte im Feld, Länge mindestens 20 Einheiten")
 return checks
end
-- Drain editing: one drain zone per table, with visible endpoint grips and whole-line dragging.
local drainEditorDown,drainEditorMove,drainEditorRedraw=E.down,E.move,E.redraw
local function pointSegmentDistance(x,y,x1,y1,x2,y2)
 local dx,dy=x2-x1,y2-y1;local len=dx*dx+dy*dy
 if len==0 then return math.sqrt((x-x1)^2+(y-y1)^2) end
 local t=((x-x1)*dx+(y-y1)*dy)/len;if t<0 then t=0 elseif t>1 then t=1 end
 local px,py=x1+dx*t,y1+dy*t
 return math.sqrt((x-px)^2+(y-py)^2)
end
function E:down()
 local x,y=self:world();local d=L() and L().drain
 if self.tool=="move" and x and d then
  local h=hit(x,y)
  if not (h and h.k=="drain") then
   local _,_,s=self:origin()
   if pointSegmentDistance(x,y,d.x1,d.y1,d.x2,d.y2 or d.y1)<=16/s then
    self.objectDrag={k="drain",z="line",x=x,y=y,x1=d.x1,y1=d.y1,x2=d.x2,y2=d.y2 or d.y1};self.selected=self.objectDrag;self:redraw();return
   end
  end
 end
 drainEditorDown(self)
end
function E:move()
 local h=self.objectDrag
 if h and h.k=="drain" and h.z=="line" then
  local x,y=self:world();if x then local d=L().drain;d.x1,d.y1=h.x1+x-h.x,h.y1+y-h.y;d.x2,d.y2=h.x2+x-h.x,h.y2+y-h.y;self:redraw() end;return
 end
 drainEditorMove(self)
end
function E:redraw()
 drainEditorRedraw(self)
 local d=L() and L().drain
 if not d or not self.canvas then return end
 self._drainGrips=self._drainGrips or {}
 for i,q in ipairs({{x=d.x1,y=d.y1},{x=d.x2,y=d.y2 or d.y1}}) do
  -- Buttons render above the artwork and give each endpoint a reliable hit target.
  local g=self._drainGrips[i]
  if not g then
   local endpoint=i
   g=CreateFrame("Button",nil,self.canvas);g:SetFrameLevel(self.canvas:GetFrameLevel()+10)
   g.outer=g:CreateTexture(nil,"OVERLAY");g.outer:SetAllPoints();g.outer:SetColorTexture(1,.12,.08,1)
   g.inner=g:CreateTexture(nil,"OVERLAY",nil,1);g.inner:SetPoint("TOPLEFT",2,-2);g.inner:SetPoint("BOTTOMRIGHT",-2,2);g.inner:SetColorTexture(.18,.02,.02,1)
   g:SetScript("OnMouseDown",function()
    if E.tool~="move" then return end
    local x,y=E:world();if not x then return end
    E.objectDrag={k="drain",z=(endpoint==1 and "a" or "b")};E.selected=E.objectDrag;E:redraw()
   end)
   g:SetScript("OnMouseUp",function() if E.objectDrag and E.objectDrag.k=="drain" then E.objectDrag=nil;E:redraw() end end)
   self._drainGrips[i]=g
  end
  local x,y,s=self:point(q.x,q.y);local z=14;g:SetSize(z,z);g:ClearAllPoints();g:SetPoint("CENTER",self.canvas,"TOPLEFT",x,-y);g:Show()
 end
end

-- Four-corner drain authoring.  Old two-point drains are upgraded only in the editor;
-- the game logic remains backward compatible with existing table definitions.
local quadSetTable,quadDown,quadMove,quadRedraw=E.setTable,E.down,E.move,E.redraw
local function drainPoints(d)
 if not d then return nil end
 if not d.points or #d.points<4 then
  local x1,y1,x2,y2=d.x1 or 112,d.y1 or 430,d.x2 or 168,d.y2 or d.y1 or 430
  local dx,dy=x2-x1,y2-y1;local len=math.sqrt(dx*dx+dy*dy);if len<.01 then len=1;dx,dy=1,0 end
  local nx,ny=-dy/len*5,dx/len*5
  d.points={{x=x1+nx,y=y1+ny},{x=x2+nx,y=y2+ny},{x=x2-nx,y=y2-ny},{x=x1-nx,y=y1-ny}}
 end
 return d.points
end
local function syncDrainLine(d)
 local p=drainPoints(d);if not p then return end
 d.x1,d.y1,d.x2,d.y2=p[1].x,p[1].y,p[2].x,p[2].y
end
local function dragPoint(i)
 local d=L() and L().drain;local p=drainPoints(d)
 if E.tool~="move" or not p then return end
 E.objectDrag={k="drain",z="point",i=i};E.selected=E.objectDrag;E:redraw()
end
function E:setTable(id)
 quadSetTable(self,id);local d=L() and L().drain;if d then syncDrainLine(d) end;self:redraw()
end
function E:down()
 local x,y=self:world();local d=L() and L().drain;local p=drainPoints(d)
 if self.tool=="move" and x and p then
  local _,_,s=self:origin();local best,which=14/s,nil
  for i,q in ipairs(p) do local z=math.sqrt((x-q.x)^2+(y-q.y)^2);if z<best then best,which=z,i end end
  if which then dragPoint(which);return end
  for i=1,#p do local a,b=p[i],p[(i%#p)+1]
   if pointSegmentDistance(x,y,a.x,a.y,b.x,b.y)<=12/s then
    local original={};for j,q in ipairs(p) do original[j]={x=q.x,y=q.y} end
    self.objectDrag={k="drain",z="area",x=x,y=y,points=original};self.selected=self.objectDrag;self:redraw();return
   end
  end
 end
 quadDown(self)
end
function E:move()
 local h=self.objectDrag;local d=L() and L().drain;local p=drainPoints(d)
 if h and h.k=="drain" and h.z=="point" and p then
  local x,y=self:world();if x then p[h.i].x,p[h.i].y=x,y;syncDrainLine(d);self:redraw() end;return
 end
 if h and h.k=="drain" and h.z=="area" and p then
  local x,y=self:world();if x then for i,q in ipairs(p) do q.x=h.points[i].x+x-h.x;q.y=h.points[i].y+y-h.y end;syncDrainLine(d);self:redraw() end;return
 end
 quadMove(self)
end
local function quadLine(t,a,b)
 local x1,y1=E:point(a.x,a.y);local x2,y2=E:point(b.x,b.y);local dx,dy=x2-x1,y2-y1
 t:SetTexture(WHITE);t:SetVertexColor(1,.15,.12,1);t:SetSize(math.max(2,math.sqrt(dx*dx+dy*dy)),3);t:ClearAllPoints();t:SetPoint("CENTER",E.canvas,"TOPLEFT",(x1+x2)*.5,-((y1+y2)*.5));if t.SetRotation then t:SetRotation(-math.atan2(dy,dx)) end;t:Show()
end
function E:redraw()
 local d=L() and L().drain;if d then syncDrainLine(d) end
 quadRedraw(self)
 local p=drainPoints(d);if not p or not self.canvas then return end
 self._drainQuadLines=self._drainQuadLines or {}
 for i=1,#p-1 do local t=self._drainQuadLines[i] or self.canvas:CreateTexture(nil,"HIGHLIGHT",nil,5);self._drainQuadLines[i]=t;quadLine(t,p[i],p[i+1]) end
 for i=#p,#self._drainQuadLines do self._drainQuadLines[i]:Hide() end
 self._drainGrips=self._drainGrips or {}
 for i,q in ipairs(p) do
  local pointIndex=i
  local g=self._drainGrips[i]
  if not g then
   g=CreateFrame("Button",nil,self.canvas);g:SetFrameLevel(self.canvas:GetFrameLevel()+11);g.outer=g:CreateTexture(nil,"OVERLAY");g.outer:SetAllPoints();g.outer:SetColorTexture(1,.12,.08,1);g.inner=g:CreateTexture(nil,"OVERLAY",nil,1);g.inner:SetPoint("TOPLEFT",2,-2);g.inner:SetPoint("BOTTOMRIGHT",-2,2);g.inner:SetColorTexture(.18,.02,.02,1);self._drainGrips[i]=g
  end
  g:SetScript("OnMouseDown",function() dragPoint(pointIndex) end);g:SetScript("OnMouseUp",function() if E.objectDrag and E.objectDrag.k=="drain" then E.objectDrag=nil;E:redraw() end end)
  local x,y=E:point(q.x,q.y);g:SetSize(14,14);g:ClearAllPoints();g:SetPoint("CENTER",E.canvas,"TOPLEFT",x,-y);g:Show()
 end
end
-- Keep the complete drain perimeter above the playfield artwork on every client.
local perimeterRedraw=E.redraw
function E:redraw()
 perimeterRedraw(self)
 local d=L() and L().drain;local p=drainPoints(d)
 if not p or not self.canvas then return end
 self._drainPerimeter=self._drainPerimeter or {}
 for i=1,#p-1 do
  local edge=self._drainPerimeter[i]
  if not edge then
   edge=CreateFrame("Frame",nil,self.canvas);edge:SetFrameLevel(self.canvas:GetFrameLevel()+9)
   edge.tex=edge:CreateTexture(nil,"ARTWORK");edge.tex:SetAllPoints();edge.tex:SetTexture(WHITE);edge.tex:SetVertexColor(1,.12,.08,1)
   self._drainPerimeter[i]=edge
  end
  local a,b=p[i],p[i+1];local x1,y1=E:point(a.x,a.y);local x2,y2=E:point(b.x,b.y);local dx,dy=x2-x1,y2-y1
  edge:SetSize(math.max(2,math.sqrt(dx*dx+dy*dy)),4);edge:ClearAllPoints();edge:SetPoint("CENTER",E.canvas,"TOPLEFT",(x1+x2)*.5,-((y1+y2)*.5));if edge.tex.SetRotation then edge.tex:SetRotation(-math.atan2(dy,dx)) end;edge:Show()
 end
 for i=#p,#self._drainPerimeter do self._drainPerimeter[i]:Hide() end
end
-- A deleted drain must also release every cached editor overlay immediately.
local drainCleanupRedraw=E.redraw
function E:redraw()
 drainCleanupRedraw(self)
 local d=L() and L().drain
 if d then return end
 for _,g in ipairs(self._drainGrips or {}) do g:Hide() end
 for _,t in ipairs(self._drainQuadLines or {}) do t:Hide() end
 for _,edge in ipairs(self._drainPerimeter or {}) do edge:Hide() end
end