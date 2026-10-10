local A=FlightpathArcade
local L=A.Logic
local gold={0.95,0.73,0.32}
local names={mines='Minesweeper',gems='Gem matching',snake='Snake',memory='Memory pairs'}
local atlas='Interface\\AddOns\\FlightpathArcade\\Media\\Arcade.tga'
local function sprite(texture,id)
 if texture.sprite==id then return end
 texture.sprite=id
 texture:SetTexture(atlas)
 local x,y=(id-1)%8,math.floor((id-1)/8)
 texture:SetTexCoord((x*64+4)/512,(x*64+60)/512,(y*64+4)/256,(y*64+60)/256)
end
local help={mines='Left click: reveal   /   Right click: flag\nFind all 54 safe squares. Your first reveal is safe.',gems='Click neighboring gems to swap. Match three or more.\n20 moves per level. Reach the target below; invalid swaps are free.',snake='Click Resume to capture arrows / WASD. Space pauses.\nEat apples. Avoid walls and yourself. Escape releases keys.',memory='Find eight matching pairs. Click to turn cards.\nMismatches turn back after a short peek.'}
local function label(parent,text,x,y,size)
 local t=parent:CreateFontString(nil,'OVERLAY','GameFontNormal'); t:SetPoint('TOPLEFT',x,y); t:SetText(text)
 if size then t:SetFont(STANDARD_TEXT_FONT,size,'') end return t
end
local function fantasyBorder(f)
 -- Eight slices from the padded Kenney border tile; fixed-size corners avoid
 -- stretching the ornament as the window changes scale.
 local pieces={
  {'TOPLEFT',2,-2,'TOPLEFT',26,-26,0,.4,0,.4},
  {'TOPRIGHT',-26,-2,'TOPRIGHT',-2,-26,.6,1,0,.4},
  {'BOTTOMLEFT',2,26,'BOTTOMLEFT',26,2,0,.4,.6,1},
  {'BOTTOMRIGHT',-26,26,'BOTTOMRIGHT',-2,2,.6,1,.6,1},
  {'TOPLEFT',26,-2,'TOPRIGHT',-26,-26,.4,.6,0,.4},
  {'BOTTOMLEFT',26,26,'BOTTOMRIGHT',-26,2,.4,.6,.6,1},
  {'TOPLEFT',2,-26,'BOTTOMLEFT',26,26,0,.4,.4,.6},
  {'TOPRIGHT',-26,-26,'BOTTOMRIGHT',-2,26,.6,1,.4,.6}}
 for _,p in ipairs(pieces) do
  local t=f:CreateTexture(nil,'BORDER'); t:SetTexture(atlas)
  t:SetTexCoord((4+56*p[7])/512,(4+56*p[8])/512,(196+56*p[9])/256,(196+56*p[10])/256)
  t:SetPoint('TOPLEFT',f,p[1],p[2],p[3]); t:SetPoint('BOTTOMRIGHT',f,p[4],p[5],p[6])
 end
end
local function skinState(b)
 local state=not b:IsEnabled() and 4 or b.pressed and 3 or b.hovered and 2 or 1
 b.skinState=state
 local ranges={{4,16},{16,240},{240,252}}
 for i,t in ipairs(b.skin) do t:SetTexCoord(ranges[i][1]/256,ranges[i][2]/256,((state-1)*64+4)/256,((state-1)*64+60)/256) end
 if state==4 then b.text:SetTextColor(0.78,0.8,0.82) else b.text:SetTextColor(1,0.9,0.7) end
end
local function button(parent,text,x,y,w,h,fn,isCell)
 local b=CreateFrame('Button',nil,parent,'BackdropTemplate'); b:SetSize(w,h); b:SetPoint('TOPLEFT',x,y)
 b.text=b:CreateFontString(nil,'OVERLAY','GameFontNormal'); b.text:SetPoint('CENTER'); b.text:SetText(text)
 if not isCell then
  b.skin={}; local edge=math.min(12,h/3)
  for i=1,3 do local t=b:CreateTexture(nil,'BACKGROUND'); t:SetTexture('Interface\\AddOns\\FlightpathArcade\\Media\\Buttons.tga'); b.skin[i]=t end
  b.skin[1]:SetPoint('TOPLEFT',0,0); b.skin[1]:SetPoint('BOTTOMRIGHT',b,'BOTTOMLEFT',edge,0)
  b.skin[2]:SetPoint('TOPLEFT',edge,0); b.skin[2]:SetPoint('BOTTOMRIGHT',-edge,0)
  b.skin[3]:SetPoint('TOPLEFT',b,'TOPRIGHT',-edge,0); b.skin[3]:SetPoint('BOTTOMRIGHT',0,0)
  b:SetScript('OnEnter',function(self) self.hovered=true; skinState(self) end)
  b:SetScript('OnLeave',function(self) self.hovered=false; self.pressed=false; skinState(self) end)
  b:SetScript('OnMouseDown',function(self) self.pressed=true; skinState(self) end)
  b:SetScript('OnMouseUp',function(self) self.pressed=false; skinState(self) end)
  b:SetScript('OnEnable',function(self) self.pressed=false; skinState(self) end)
  b:SetScript('OnDisable',function(self) self.pressed=false; skinState(self) end)
  b:SetScript('OnHide',function(self) self.pressed=false; self.hovered=false; skinState(self) end)
  b:SetScript('OnClick',fn); skinState(b); return b
 end
 b:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
 b:SetBackdropColor(0.105,0.15,0.2,1); b:SetBackdropBorderColor(0.25,0.34,0.4,1)
 b:SetScript('OnClick',fn); b:SetScript('OnEnter',function(self) self:SetBackdropBorderColor(unpack(gold)) end)
 b:SetScript('OnLeave',function(self)
  if self.selected then self:SetBackdropBorderColor(1,1,1,1)
  else self:SetBackdropBorderColor(0.25,0.34,0.4,1) end
 end)
 return b
end
A.UI={label=label,button=button,border=fantasyBorder}
function A:BuildUI()
 self.layout=nil
 local f=CreateFrame('Frame','FlightpathArcadeWindow',UIParent,'BackdropTemplate'); self.window=f
 f:SetSize(480,550); f:SetPoint('CENTER'); f:SetFrameStrata('DIALOG'); f:SetClampedToScreen(true)
 f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'})
 f:SetBackdropColor(0.035,0.055,0.08,0.98)
 fantasyBorder(f)
 f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag('LeftButton')
 f:SetScript('OnDragStart',f.StartMoving); f:SetScript('OnDragStop',f.StopMovingOrSizing)
 self.brand=label(f,'FLIGHTPATH ARCADE',22,-24,22); self.brand:SetTextColor(unpack(gold))
 label(f,'Small games. Long journeys.',23,-49,12):SetTextColor(0.6,0.7,0.78)
 self.closeButton=button(f,'X',424,-24,28,28,function() self:Close() end)
 self.back=button(f,'< Lobby',22,-78,100,28,function() self:Pause(); self.screen='lobby'; self:Render() end)
 self.settingsButton=button(f,'Settings',350,-78,108,28,function() self:Pause(); self.screen='settings'; self:Render() end)
 self.content=CreateFrame('Frame',nil,f); self.content:SetPoint('TOPLEFT',22,-120); self.content:SetSize(436,355)
 self.title=label(f,'',140,-84,15)
 self.status=label(f,'',22,-488,13); self.status:SetWidth(436); self.status:SetJustifyH('LEFT')
 self.hint=label(self.content,'',0,0,12); self.hint:SetWidth(436); self.hint:SetJustifyH('LEFT'); self.hint:SetTextColor(0.7,0.78,0.83)
 self.restart=button(f,'Restart',240,-515,100,25,function() self:RestartGame() end)
 self.newRun=button(f,'New run',22,-515,110,25,function() self:Start('gems',1) end)
 self.pause=button(f,'Resume',350,-515,108,25,function() if self.paused then self:Resume() else self:Pause() end self:Render() end)
 self.directions={}
 for i,key in ipairs({'LEFT','UP','DOWN','RIGHT'}) do
  local direction=key
  self.directions[i]=button(f,({'<','^','v','>'})[i],22+(i-1)*43,-515,38,25,function()
   if self.game and self.game.kind=='snake' and self.game.status=='playing' then
    self:Pause(); self.paused=false; L.turn(self.game,direction); self:Render()
   end
  end)
 end
 self.cells={}; for i=1,144 do
  local index=i; local b=button(self.content,'',0,0,24,24,function(_,mouse) self:Cell(index,mouse) end,true)
  b:RegisterForClicks('LeftButtonUp','RightButtonUp'); self.cells[i]=b; b:Hide()
  b.art=b:CreateTexture(nil,'ARTWORK'); b.art:SetPoint('TOPLEFT',3,-3); b.art:SetPoint('BOTTOMRIGHT',-3,3)
 end
 self.gemOverlay=CreateFrame('Frame',nil,self.content); self.gemOverlay:SetPoint('TOPLEFT',89,-55); self.gemOverlay:SetSize(258,258); self.gemOverlay:SetClipsChildren(true)
 self.gemOverlay:EnableMouse(false)
 self.gemSprites={}
 for i=1,36 do local t=self.gemOverlay:CreateTexture(nil,'OVERLAY'); self.gemSprites[i]=t; t:SetSize(34,34) end
 self.gemOverlay:Hide()
 self.gemResult=CreateFrame('Frame',nil,self.content,'BackdropTemplate')
 self.gemResult:SetPoint('TOPLEFT',89,-55); self.gemResult:SetSize(258,258); self.gemResult:EnableMouse(true)
 self.gemResult:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'}); self.gemResult:SetBackdropColor(0.035,0.055,0.08,0.98)
 fantasyBorder(self.gemResult)
 self.resultTitle=label(self.gemResult,'',20,-24,20); self.resultTitle:SetWidth(218); self.resultTitle:SetJustifyH('LEFT')
 self.resultDetail=label(self.gemResult,'',20,-59,12); self.resultDetail:SetWidth(218); self.resultDetail:SetJustifyH('LEFT')
 self.resultPrimary=button(self.gemResult,'',20,-120,218,32,function() self:ResultAction('primary') end)
 self.resultSecondary=button(self.gemResult,'',20,-160,218,32,function() self:ResultAction('secondary') end)
 self.resultBack=button(self.gemResult,'Back to lobby',20,-200,218,32,function() self:ResultAction('back') end)
 self.gemResult:Hide()
 self.cards={}
 for i,kind in ipairs({'mines','gems','snake','memory'}) do
  local k=kind; self.cards[i]=button(self.content,names[kind],0,-35-(i-1)*70,436,56,function() self:SelectGame(k) end)
  local icon=self.cards[i]:CreateTexture(nil,'ARTWORK'); icon:SetSize(40,40); icon:SetPoint('LEFT',12,0); sprite(icon,({6,1,9,17})[i])
 end
 self.options={}
 for i,entry in ipairs({{'autoOpen','Open when a flight begins'},{'autoClose','Close when a flight ends'},{'minimap','Show minimap button'}}) do
  local key,text=entry[1],entry[2]
  local b=button(self.content,'',0,-40-(i-1)*60,436,44,function() self.db[key]=not self.db[key]; self:UpdateMinimap(); self:Render() end)
  b.key=key; b.caption=text; self.options[i]=b
 end
 self.scaleLabel=label(self.content,'',0,-222,12)
 self.scaleButtons={}
 for i,entry in ipairs({{'Smaller',-0.1},{'Larger',0.1},{'Reset',0}}) do
  local delta=entry[2]
  self.scaleButtons[i]=button(self.content,entry[1],(i-1)*148,-250,140,34,function()
   self.db.uiScale=delta==0 and 1 or math.max(0.75,math.min(1.5,math.floor((self.db.uiScale+delta)*100+0.5)/100))
   self:FitWindow(true); self:Render()
  end)
 end
 f:SetScript('OnHide',function() self:Pause() end)
 f:SetScript('OnKeyDown',function(_,key)
  if InCombatLockdown and InCombatLockdown() then self:Pause(); self:Render(); return end
  if key=='ESCAPE' then self:Pause(); self:Render(); return end
  if key=='SPACE' then self:Pause(); self:Render(); return end
  local mapped=({W='UP',A='LEFT',S='DOWN',D='RIGHT'})[key] or key
  if self.game and self.game.kind=='snake' then L.turn(self.game,mapped) end
 end)
 f:EnableKeyboard(false)
 f:SetScript('OnUpdate',function(_,dt) self:Tick(dt) end)
 tinsert(UISpecialFrames,'FlightpathArcadeWindow'); f:Hide()
 local m=CreateFrame('Button','FlightpathArcadeMinimap',Minimap,'BackdropTemplate'); self.minimap=m
 m:SetSize(30,30); m:SetPoint('TOPLEFT',Minimap,'TOPLEFT',-7,7); m:SetFrameStrata('MEDIUM')
 local icon=m:CreateTexture(nil,'ARTWORK'); m.icon=icon
 icon:SetTexture('Interface\\AddOns\\FlightpathArcade\\Media\\Minimap.tga')
 icon:SetTexCoord(4/64,60/64,4/64,60/64)
 icon:SetPoint('TOPLEFT',0,0); icon:SetPoint('BOTTOMRIGHT',0,0)
 m:SetScript('OnClick',function() self:Toggle() end)
 m:SetScript('OnEnter',function() GameTooltip:SetOwner(m,'ANCHOR_LEFT'); GameTooltip:AddLine('Flightpath Arcade'); GameTooltip:AddLine('Click to open or close',1,1,1); GameTooltip:Show() end)
 m:SetScript('OnLeave',function() GameTooltip:Hide() end)
end
function A:FitWindow(recenter)
 -- UIParent sizes are logical UI units, not physical display pixels. Both the
 -- available rectangle and this window's dimensions use that same space.
 local width,height=UIParent:GetWidth(),UIParent:GetHeight()
 if not width or not height or width<=32 or height<=32 then return end
 local scale=math.min(self.db.uiScale,(width-32)/480,(height-32)/550)
 self.appliedScale=scale; self.effectiveScale=scale*UIParent:GetEffectiveScale()
 self.window:SetScale(scale)
 if recenter then self.window:ClearAllPoints(); self.window:SetPoint('CENTER',UIParent,'CENTER',0,0) end
end
function A:UpdateMinimap() self.minimap:SetShown(self.db.minimap) end
function A:Pause()
 self.paused=true; self.keyboardCaptured=false
 -- Disable reception on this ordinary, non-secure frame. Do not change the
 -- restricted propagation property while entering combat or releasing focus.
 self.window:EnableKeyboard(false)
end
function A:ReleaseChatFocus()
 -- Forever exposes these helpers on ChatFrameUtil. Fail closed if unavailable
 -- or rejected, so Resume never captures keys while chat may still own focus.
 local chat=ChatFrameUtil
 if type(chat)~='table' or type(chat.GetActiveWindow)~='function' or type(chat.DeactivateChat)~='function' then return false end
 local ok,edit=pcall(chat.GetActiveWindow)
 if not ok then return false end
 if edit then
  if not pcall(chat.DeactivateChat,edit) then return false end
  ok,edit=pcall(chat.GetActiveWindow)
 end
 return ok and not edit
end
function A:Resume()
 if not self.game or (self.game.status~='playing' and not self.game.animation) or self.screen~='game' or not self.window:IsShown() then return false end
 if self.game.kind=='snake' then
  -- Prepare propagation BEFORE enabling input or changing game/chat state.
  -- A restricted/unsupported API must leave the game paused and keys free.
  if InCombatLockdown and InCombatLockdown() then return false end
  self:Pause()
  local ok=pcall(self.window.SetPropagateKeyboardInput,self.window,false)
  if not ok then return false end
  if not self:ReleaseChatFocus() then return false end
  self.window:EnableKeyboard(true); self.keyboardCaptured=true
 end
 self.paused=false
 return true
end
function A:Open() self:FitWindow(false); self.window:Show(); self.screen=self.screen or 'lobby'; self:Pause(); self:Render() end
function A:Close() self.window:Hide() end
function A:Toggle() if self.window:IsShown() then self:Close() else self:Open() end end
function A:Start(kind,level,rng)
 self:Pause()
 if self.game and self.game.kind=='gems' then self.gemSession=self.game end
 self.game=kind=='gems' and L.gems(rng,level) or L[kind]()
 if kind=='gems' then self.gemSession=self.game end
 self.screen='game'; self.elapsed=0; self.resultGame=nil
 if kind~='snake' then self:Resume() end
 self:Render()
end
function A:SelectGame(kind)
 if kind=='gems' and self.gemSession then
  self:Pause(); self.game=self.gemSession; self.screen='game'; self.elapsed=0; self:Render()
 else self:Start(kind) end
end
function A:RestartGame()
 local s=self.game
 if s then self:Start(s.kind,s.kind=='gems' and s.level or nil,s.kind=='gems' and s.rng or nil) end
end
function A:ResultAction(action)
 local s=self.resultGame
 if not self.window:IsShown() or self.screen~='game' or not self.gemResult:IsShown() or s~=self.game or not s or s.animation or s.status=='playing' or s.resultConsumed then return false end
 if action=='back' then self:Pause(); self.screen='lobby'; self:Render(); return true end
 if action~='primary' and action~='secondary' then return false end
 local level=s.level or 1
 if action=='primary' and s.status=='won' then level=level<10 and level+1 or 1
 elseif action=='secondary' and s.status=='lost' then level=1 end
 s.resultConsumed=true -- token consumed before replacing the round; queued clicks cannot advance twice
 self:Start('gems',level,s.rng)
 return true
end
function A:ShowGemResult()
 local s=self.game
 if self.screen~='game' or s.kind~='gems' or s.animation or s.status=='playing' then return end
 local level=math.max(self.content:GetFrameLevel(),self.gemOverlay:GetFrameLevel())
 for i=1,36 do level=math.max(level,self.cells[i]:GetFrameLevel()) end
 self.gemResult:SetFrameLevel(level+2)
 self.resultGame=s; self:Pause()
 local won=s.status=='won'; local last=won and s.level==10
 self.resultTitle:SetText(last and 'All levels complete!' or won and 'Level complete!' or 'Out of moves')
 self.resultTitle:SetTextColor(unpack(gold))
 self.resultDetail:SetText('Level '..s.level..' - Target '..s.target..'\nScore '..s.score..' - '..s.moves..' moves left\n'..(last and 'A perfect journey. Play again?' or won and 'Ready for the next challenge?' or 'Try again with a fresh board.'))
 self.resultPrimary.text:SetText(won and (last and 'New run' or 'Next level') or 'Retry level')
 self.resultSecondary.text:SetText(won and 'Retry level' or 'New run')
 self.gemResult:Show()
end
function A:Cell(i,mouse)
 local s=self.game; if self.screen~='game' or self.paused or not s or s.status~='playing' or s.animation or self.gemResult:IsShown() then return end
 if s.kind=='mines' then L.reveal(s,i,mouse=='RightButton')
 elseif s.kind=='memory' then L.flip(s,i)
 elseif s.kind=='gems' then
  if s.selected then L.planSwap(s,s.selected,i); s.selected=nil else s.selected=i end
 end
 self:Render()
end
function A:Tick(dt)
 local s=self.game
 if self.keyboardCaptured and InCombatLockdown and InCombatLockdown() then self:Pause(); self:Render(); return end
 if self.paused or self.screen~='game' or not s or not self.window:IsShown() then return end
 if s.animation then
  L.animationTick(s,dt)
  if s.animation then self:PaintAnimation() else self:Render() end
  return
 end
 if s.status~='playing' then return end
 if s.kind=='snake' then
  self.elapsed=self.elapsed+dt
  if self.elapsed>=0.18 then self.elapsed=self.elapsed%0.18; L.snakeTick(s); self:Render() end
 elseif s.kind=='memory' and s.wait then L.memoryTick(s,dt); if not s.wait then self:Render() end end
end
function A:PaintAnimation()
 local s=self.game; local anim=s.animation; if not anim then return end
 local p=anim.phases[anim.index]; local t=math.min(1,anim.time/p.duration); local ease=t*t*(3-2*t)
 -- Draw layers order regions only within a frame level. Tile Buttons and this
 -- sibling Frame can otherwise tie, allowing button backdrops to cover gems.
 -- Re-evaluate while animating in case WoW raises a clicked tile or its parent.
 local tileLevel=self.content:GetFrameLevel()
 for i=1,36 do tileLevel=math.max(tileLevel,self.cells[i]:GetFrameLevel()) end
 if self.gemOverlay:GetFrameLevel()~=tileLevel+1 then self.gemOverlay:SetFrameLevel(tileLevel+1) end
 self.gemOverlay:Show()
 for i=1,36 do
  local tex=self.gemSprites[i]; local x,y=(i-1)%6,math.floor((i-1)/6); local alpha=1; local scale=1
  if p.kind=='swap' and (i==p.a or i==p.b) then
   local j=i==p.a and p.b or p.a; x=x+(((j-1)%6)-x)*ease; y=y+(math.floor((j-1)/6)-y)*ease
  elseif p.kind=='fall' then y=p.origins[i]+(y-p.origins[i])*ease
  elseif p.kind=='clear' and p.found[i] then alpha=1-t; scale=1-0.65*t
  elseif p.kind=='highlight' and p.found[i] then scale=1+0.13*math.sin(t*math.pi)
  elseif p.kind=='refill' then alpha=t end
  sprite(tex,p.board[i]); tex:ClearAllPoints(); tex:SetPoint('CENTER',self.gemOverlay,'TOPLEFT',x*43+20,-y*43-20)
  tex:SetSize(34*scale,34*scale); tex:SetAlpha(alpha); tex:Show()
 end
 self.status:SetText('Level '..(s.level or 1)..'   Score '..(p.score or anim.score)..' / '..(s.target or 600)..'   Moves '..s.moves..'   |   '..(self.paused and 'Paused' or p.kind=='swap' and 'Swapping' or p.kind=='fall' and 'Falling' or 'Resolving'))
end
function A:Render()
 local playing=self.screen=='game'; local settings=self.screen=='settings'
 local layout=self.screen..(playing and self.game.kind or '')
 local layoutChanged=self.layout~=layout; self.layout=layout
 self.gemOverlay:Hide()
 self.gemResult:Hide(); self.resultGame=nil
 if layoutChanged then for _,b in ipairs(self.cells) do b:Hide(); b.paint=nil end end
 for _,b in ipairs(self.cards) do b:SetShown(not playing and not settings) end
 self.cards[2].text:SetText(self.gemSession and 'Gem matching (continue)' or 'Gem matching')
 for _,b in ipairs(self.options) do b:SetShown(settings); b.text:SetText((self.db[b.key] and '|cff80dcaaON|r   ' or '|cff8999aaOFF|r   ')..b.caption) end
 self.scaleLabel:SetShown(settings)
 self.scaleLabel:SetText('Scale: '..math.floor(self.db.uiScale*100+0.5)..'% of game UI'..((self.appliedScale or self.db.uiScale)<self.db.uiScale and ' - fitted to screen' or ''))
 for _,b in ipairs(self.scaleButtons) do b:SetShown(settings) end
 self.scaleButtons[1]:SetEnabled(self.db.uiScale>0.75); self.scaleButtons[2]:SetEnabled(self.db.uiScale<1.5)
 self.restart:SetShown(playing); self.pause:SetShown(playing); self.back:SetShown(playing or settings)
 self.newRun:SetShown(playing and self.game.kind=='gems')
 self.restart.text:SetText(playing and self.game.kind=='gems' and 'Retry level' or 'Restart')
 for _,b in ipairs(self.directions) do b:SetShown(playing and self.game.kind=='snake') end
 self.title:SetText(settings and 'Preferences' or playing and names[self.game.kind] or 'Choose a game')
 if layoutChanged then self.title:ClearAllPoints(); self.title:SetPoint('TOPLEFT',(playing or settings) and 140 or 22,-84) end
 self.hint:SetText(settings and 'Preferences are saved across reloads.' or playing and help[self.game.kind] or 'A little diversion between destinations.')
 self.status:SetText(self.inFlight and 'In flight. Enjoy the journey.' or 'Ready whenever you are.  /fpa')
 if not playing then return end
 local s=self.game; local size=s.kind=='memory' and 63 or s.kind=='snake' and 24 or s.kind=='gems' and 43 or 34
 local left=math.floor((436-s.w*size)/2)
 local occupied={} if s.body then for j,i in ipairs(s.body) do occupied[i]=j end end
 for i=1,s.w*s.h do
  local b=self.cells[i]
  if layoutChanged then
   b:ClearAllPoints(); b:SetPoint('TOPLEFT',left+((i-1)%s.w)*size,-55-math.floor((i-1)/s.w)*size); b:SetSize(size-3,size-3); b:Show()
  end
  local text=''; local c={0.09,0.13,0.17}; local art=nil
  if s.kind=='mines' then
   if s.open[i] or s.status=='lost' and s.board[i]==-1 then
    if s.board[i]==-1 then art=6 else text=s.board[i]==0 and '' or tostring(s.board[i]) end; c={0.18,0.23,0.25}
   elseif s.flags[i] then art=7 else art=8 end
  elseif s.kind=='gems' then if not s.animation then art=s.board[i] end
  elseif s.kind=='memory' then if s.matched[i] or s.first==i or s.second==i then art=16+s.board[i] else art=16 end
  elseif s.kind=='snake' then if occupied[i] then art=occupied[i]==1 and ({RIGHT=9,DOWN=10,LEFT=11,UP=12})[s.dir] or 13 elseif s.food==i then art=14 end end
  local paint=text..':'..tostring(art)..':'..c[1]..':'..c[2]..':'..c[3]..':'..tostring(s.selected==i)
  b.selected=s.selected==i
  if b.paint~=paint then
   b.paint=paint; b:SetBackdropColor(c[1],c[2],c[3],1); b.text:SetText(text); b.text:SetTextColor(1,1,1)
   b.art:SetShown(art~=nil); if art then sprite(b.art,art) end
   b:SetBackdropBorderColor(s.selected==i and 1 or 0.25,s.selected==i and 1 or 0.34,s.selected==i and 1 or 0.4,1)
  end
 end
 local detail='Score: '..s.score
 if s.kind=='mines' then detail='Safe squares: '..s.score..' / 54' elseif s.kind=='gems' then detail='Level '..s.level..'   Score '..s.score..' / '..s.target..'   Moves '..s.moves elseif s.kind=='memory' then detail='Pairs: '..s.score..' / 8    Turns: '..s.moves end
 self.status:SetText(detail..'   |   '..(s.status=='won' and 'You won!' or s.status=='lost' and 'Game over' or self.paused and 'Paused' or 'Playing'))
 self.pause.text:SetText(self.paused and 'Resume' or 'Pause')
 if s.animation then self:PaintAnimation()
 elseif s.status~='playing' then self:Pause(); self.pause:Hide(); if s.kind=='gems' then self:ShowGemResult() end end
end
