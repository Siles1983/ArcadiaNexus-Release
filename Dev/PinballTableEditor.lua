local AN = _G.ArcadiaNexus
AN.PinballTableEditor = {}
local E = AN.PinballTableEditor
local UI = AN.UI
local WHITE = "Interface\\Buttons\\WHITE8X8"
local W, H = 280, 440
E.id, E.tool, E.lines, E.rings = "darkmoon_midway", "move", {}, {}

local function copy(list)
 local out = {}
 for i=1,#(list or {}) do local r={} for k,v in pairs(list[i]) do r[k]=v end out[i]=r end
 return out
end
local function def(id) local L=AN.DMP_Logic return L and L.GetTable and L:GetTable(id) end
local function tex(k,s) local A=AN.DMP_Assets return A and A.Get and A.Get(k,s) end
local function db()
 local S=AN.DevStore
 if not S or not S.Get then return nil end
 local d=S.Get(); d.pinballEditor=d.pinballEditor or {}; return d.pinballEditor
end
local function fresh(id)
 local d=def(id); if not d then return nil end
 return {id=id,walls=copy(d.walls),posts=copy(d.posts),wallNo=1,postNo=1}
end
local function save()
 local b,d=db(),E.draft
 if b and d then b[d.id]={walls=copy(d.walls),posts=copy(d.posts),wallNo=d.wallNo,postNo=d.postNo} end
end
local function load(id)
 local d,b=fresh(id),db(); local x=b and b[id]
 if d and x then d.walls,d.posts,d.wallNo,d.postNo=copy(x.walls),copy(x.posts),x.wallNo or 1,x.postNo or 1 end
 return d
end
local function dist(a,b,c,d) local x,y=a-c,b-d return math.sqrt(x*x+y*y) end
function E:scale() return math.min((self.view:GetWidth()-20)/W,(self.view:GetHeight()-20)/H) end
function E:origin() local s=self:scale() return (self.view:GetWidth()-W*s)*.5,(self.view:GetHeight()-H*s)*.5,s end
function E:world()
 local x,y=GetCursorPosition(); local v=self.view; local l,t=v:GetLeft(),v:GetTop(); if not l or not t then return nil end
 local ox,oy,s=self:origin(); x,y=(x/v:GetEffectiveScale()-l-ox)/s,(t-y/v:GetEffectiveScale()-oy)/s
 if x<0 or y<0 or x>W or y>H then return nil end
 return math.floor(x*2+.5)/2,math.floor(y*2+.5)/2
end
function E:point(x,y) local ox,oy,s=self:origin() return ox+x*s,oy+y*s,s end
function E:get(pool,n)
 local t=pool[n]; if not t then t=self.canvas:CreateTexture(nil,"ARTWORK"); pool[n]=t end; t:Show(); return t
end
function E:line(n,w,r,g,b)
 local t=self:get(self.lines,n); local x1,y1=self:point(w.ax,w.ay); local x2,y2=self:point(w.bx,w.by); local dx,dy=x2-x1,y2-y1
 t:SetTexture(WHITE); t:SetSize(math.max(2,math.sqrt(dx*dx+dy*dy)),3); t:ClearAllPoints(); t:SetPoint("CENTER",self.canvas,"TOPLEFT",(x1+x2)*.5,-((y1+y2)*.5)); t:SetVertexColor(r,g,b,.95)
 if t.SetRotation then t:SetRotation(-math.atan2(dy,dx)) end
end
function E:ring(n,p)
 local t=self:get(self.rings,n); local x,y,s=self:point(p.x,p.y); local z=math.max(8,p.r*2*s)
 t:SetTexture(tex("fx","ring") or WHITE); t:SetSize(z,z); t:ClearAllPoints(); t:SetPoint("CENTER",self.canvas,"TOPLEFT",x,-y); t:SetVertexColor(1,.7,.15,1)
end
function E:redraw()
 if not self.draft then return end
 for i=1,#self.draft.walls do self:line(i,self.draft.walls[i],.2,.85,1) end
 for i=#self.draft.walls+1,#self.lines do self.lines[i]:Hide() end
 for i=1,#self.draft.posts do self:ring(i,self.draft.posts[i]) end
 for i=#self.draft.posts+1,#self.rings do self.rings[i]:Hide() end
 if self.drag and self.drag.kind=="new" then local x,y=self:world(); if x then self:line(#self.draft.walls+1,{ax=self.drag.x,ay=self.drag.y,bx=x,by=y},.3,1,.3) end end
 local x,y=self:world(); self.status:SetText(self.draft.id.."  |cffaaaaaa"..#self.draft.walls.." walls, "..#self.draft.posts.." posts|r"..(x and string.format("  %.1f / %.1f",x,y) or ""))
end
function E:find(x,y)
 local _,_,s=self:origin(); local hit,best=nil,12/s
 for i=1,#self.draft.walls do local w=self.draft.walls[i]; local a,b=dist(x,y,w.ax,w.ay),dist(x,y,w.bx,w.by); if a<best then hit,best={type="wall",i=i,p="a"},a end; if b<best then hit,best={type="wall",i=i,p="b"},b end end
 for i=1,#self.draft.posts do local p=self.draft.posts[i]; local q=dist(x,y,p.x,p.y); if q<best then hit,best={type="post",i=i},q end end
 return hit
end
function E:down()
 local x,y=self:world(); if not x then return end; local d=self.draft
 if self.tool=="wall" then self.drag={kind="new",x=x,y=y}
 elseif self.tool=="post" then d.posts[#d.posts+1]={id="post_dev_"..d.postNo,x=x,y=y,r=6}; d.postNo=d.postNo+1; save()
 elseif self.tool=="delete" then local h=self:find(x,y); if h then if h.type=="wall" then table.remove(d.walls,h.i) else table.remove(d.posts,h.i) end; save() end
 else self.drag=self:find(x,y) end
 self:redraw()
end
function E:up()
 local q,x,y=self.drag,self:world(); self.drag=nil
 if q and q.kind=="new" and x and dist(x,y,q.x,q.y)>2 then local d=self.draft; d.walls[#d.walls+1]={id="wall_dev_"..d.wallNo,ax=q.x,ay=q.y,bx=x,by=y}; d.wallNo=d.wallNo+1; save() end
 self:redraw()
end
function E:move()
 local q,x,y=self.drag,self:world(); if not q or q.kind=="new" or not x then return end
 if q.type=="post" then self.draft.posts[q.i].x,self.draft.posts[q.i].y=x,y else local w=self.draft.walls[q.i]; if q.p=="a" then w.ax,w.ay=x,y else w.bx,w.by=x,y end end
 self:redraw()
end
local function n(v) return string.format("%.1f",v):gsub("%.0$","") end
function E:export()
 local d,out=self.draft,{"-- Pinball Collider Editor: "..self.draft.id,"walls = {"}
 for i=1,#d.walls do local w=d.walls[i]; local tail=w.oneSided and string.format(", oneSided = true, nx = %s, ny = %s",n(w.nx or 0),n(w.ny or 0)) or ""; out[#out+1]=string.format('    { id = "%s", ax = %s, ay = %s, bx = %s, by = %s%s },',w.id,n(w.ax),n(w.ay),n(w.bx),n(w.by),tail) end
 out[#out+1]="},"; out[#out+1]="posts = {"
 for i=1,#d.posts do local p=d.posts[i]; out[#out+1]=string.format('    { id = "%s", x = %s, y = %s, r = %s },',p.id,n(p.x),n(p.y),n(p.r)) end
 out[#out+1]="},"
 if not self.output then local f=CreateFrame("Frame","ArcadiaNexus_PinballEditorExport",self.frame,"BackdropTemplate"); f:SetSize(680,390); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}}); local sc=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); sc:SetPoint("TOPLEFT",16,-16); sc:SetPoint("BOTTOMRIGHT",-36,16); local e=CreateFrame("EditBox",nil,sc); e:SetMultiLine(true); e:SetFontObject(GameFontHighlightSmall); e:SetWidth(620); e:SetAutoFocus(false); sc:SetScrollChild(e); f.edit=e; self.output=f end
 self.output.edit:SetText(table.concat(out,"\n")); self.output:Show(); self.output.edit:SetFocus(); self.output.edit:HighlightText()
end
function E:setTable(id) self.id,self.draft=id,load(id); self.bg:SetTexture(tex("playfield",id=="darkmoon_carousel" and "carousel" or "midway") or WHITE); self:redraw() end
function E:build()
 if self.frame then return end
 local f=CreateFrame("Frame","ArcadiaNexus_PinballTableEditor",UIParent,"BackdropTemplate"); self.frame=f; f:SetSize(900,760); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetToplevel(true); f:SetMovable(true); f:EnableMouse(true); f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}}); f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",f.StopMovingOrSizing); f:SetScript("OnHide",save)
 local title=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); title:SetPoint("TOPLEFT",12,-12); title:SetText("|cffffd700Pinball Table Editor|r"); local close=UI.CreateArcadiaButton(f,"X",28,28); close:SetPoint("TOPRIGHT",-10,-8); close:SetScript("OnClick",function() f:Hide() end)
 local side=CreateFrame("Frame",nil,f); side:SetPoint("TOPLEFT",10,-46); side:SetPoint("BOTTOMLEFT",10,96); side:SetWidth(145); local function b(s,y,fn) local q=UI.CreateArcadiaButton(side,s,128,26); q:SetPoint("TOP",0,y); q:SetScript("OnClick",fn) end
 b("Midway",-4,function() E:setTable("darkmoon_midway") end); b("Carousel",-34,function() E:setTable("darkmoon_carousel") end); b("Move",-78,function() E.tool="move" end); b("Draw wall",-108,function() E.tool="wall" end); b("Add post",-138,function() E.tool="post" end); b("Delete",-168,function() E.tool="delete" end); b("Reset table",-208,function() E:resetTable() end); b("Export Lua",-238,function() E:export() end)
 local v=CreateFrame("Frame",nil,f,"BackdropTemplate"); v:SetPoint("TOPLEFT",side,"TOPRIGHT",8,0); v:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-10,96); v:SetBackdrop({bgFile=WHITE,edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=12,insets={left=2,right=2,top=2,bottom=2}}); v:SetClipsChildren(true); v:EnableMouse(true); self.view=v; local c=CreateFrame("Frame",nil,v); c:SetAllPoints(); self.canvas=c; self.bg=c:CreateTexture(nil,"BACKGROUND")
 local function layout() local ox,oy,s=E:origin(); E.bg:ClearAllPoints(); E.bg:SetSize(W*s,H*s); E.bg:SetPoint("TOPLEFT",c,"TOPLEFT",ox,-oy) end
 v:SetScript("OnSizeChanged",function() layout(); E:redraw() end); v:SetScript("OnMouseDown",function(_,q) if q=="LeftButton" then E:down() end end); v:SetScript("OnMouseUp",function(_,q) if q=="LeftButton" then E:up() end end); v:SetScript("OnUpdate",function() if E.drag then if E.drag.kind=="new" then E:redraw() else E:move() end end end)
 local st=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); st:SetPoint("BOTTOMLEFT",12,10); st:SetPoint("BOTTOMRIGHT",-12,10); st:SetJustifyH("LEFT"); self.status=st; layout()
end
function E.Open() if not (AN.IsDevMode and AN.IsDevMode()) then return end; E:build(); E.frame:Show(); E:setTable(E.id) end
function E.Toggle() if E.frame and E.frame:IsShown() then E.frame:Hide() else E.Open() end end
SLASH_ANPINBALLEDITOR1="/anpedit"
SlashCmdList["ANPINBALLEDITOR"]=function() E.Toggle() end
