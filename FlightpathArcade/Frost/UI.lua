-- Optional fifth game: shared window, lifecycle and pooled, bounded rendering.
local A=FlightpathArcade
local S,V=A.FrostSim,A.FrostAnimation
local UI=A.UI
local art='Interface\\AddOns\\FlightpathArcade\\Media\\Frost\\'
local freshSeed=S.seedSource((time and time() or 16001)+math.floor((GetTime and GetTime() or 0)*1000))
local base={}
for _,k in ipairs({'BuildUI','Render','Pause','Resume','Start','Tick'}) do base[k]=A[k] end
local function combat() return InCombatLockdown and InCombatLockdown() end

-- Crop geometry AND texture coordinates, including transparent shadow pixels.
-- This works for regions on the field itself without relying on child clipping.
function S.crop(x,y,w,h,bw,bh,u0,u1,v0,v1)
 local l,t=math.max(0,x),math.max(0,y)
 local r,b=math.min(bw,x+w),math.min(bh,y+h)
 if r<=l or b<=t then return end
 u0,u1,v0,v1=u0 or 0,u1 or 1,v0 or 0,v1 or 1
 return l,t,r-l,b-t,u0+(u1-u0)*(l-x)/w,u0+(u1-u0)*(r-x)/w,v0+(v1-v0)*(t-y)/h,v0+(v1-v0)*(b-y)/h
end
local function cropTexture(tex,parent,x,y,w,h,bw,bh,u0,u1,v0,v1)
 local l,t,cw,ch,a,b,c,d=S.crop(x,y,w,h,bw,bh,u0,u1,v0,v1)
 if not l then tex:Hide(); return end
 tex:ClearAllPoints();tex:SetPoint('TOPLEFT',parent,'TOPLEFT',l,-t)
 tex:SetSize(cw,ch);tex:SetTexCoord(a,b,c,d);tex:Show()
end
function A:DrawFrostSprite(t,name,x,y)
 local height=(S.hazards[name] and S.hazards[name].height) or 32
 if t.frostName~=name then t:SetTexture(art..name..'.tga');t.frostName=name end
 cropTexture(t,self.frostField,math.floor(x+0.5)-16,math.floor(y+0.5)+16-height,32,height,480,520)
end
function A:BuildUI()
 base.BuildUI(self)
 self.frostKeys={};self.frostHeld={}
 self.frostArtLoaded=false
 self.frostCard=UI.button(self.content,'Frost Run',0,-315,436,32,function() self:Start('frost') end);self.frostCard:Hide()
 -- A small Settings-only discovery target; never listens to lobby keys.
 local secret=CreateFrame('Button',nil,self.window);self.frostSecret=secret
 secret:SetSize(32,32);secret:SetPoint('TOPLEFT',426,-506);secret:RegisterForClicks('LeftButtonUp')
 local icon=secret:CreateTexture(nil,'ARTWORK');self.frostSecretIcon=icon
 icon:SetSize(24,24);icon:SetPoint('CENTER',0,0);icon:SetTexture(art..'skier.tga');icon:SetAlpha(.75)
 secret:SetScript('OnEnter',function() icon:SetAlpha(1) end)
 secret:SetScript('OnLeave',function() icon:SetAlpha(.75) end)
 secret:SetScript('OnClick',function()
  if self.screen~='settings' or not self.window:IsShown() or self.codeOpen or combat() then return end
  if self.db.frostUnlocked then self:Start('frost') else self:OpenCode() end
 end)
 secret:Hide()
 local scene=CreateFrame('Frame',nil,self.content);self.frostScene=scene
 scene:SetSize(584,520);scene:SetPoint('TOPLEFT',42.8,-38);scene:SetScale(0.6);scene:EnableMouse(false)
 local field=CreateFrame('Frame',nil,scene);self.frostField=field
 field:SetPoint('TOPLEFT',52,0);field:SetSize(480,520);field:EnableMouse(false)
 local snow=field:CreateTexture(nil,'BACKGROUND');snow:SetTexture('Interface\\Buttons\\WHITE8X8');snow:SetVertexColor(0.88,0.95,0.98,1)
 cropTexture(snow,field,0,0,480,520,480,520)
 self.frostTerrain={};self.frostDecor={};self.frostPool={};self.frostGates={}
 for i=1,2 do local t=field:CreateTexture(nil,'BACKGROUND');t:SetDrawLayer('BACKGROUND',1);self.frostTerrain[i]=t end
 for i=1,4 do self.frostDecor[i]=scene:CreateTexture(nil,'BACKGROUND') end
 for i=1,48 do self.frostPool[i]=field:CreateTexture(nil,'BORDER') end
 for i=1,6 do self.frostGates[i]={field:CreateTexture(nil,'BORDER'),field:CreateTexture(nil,'BORDER')} end
 self.frostSkier=field:CreateTexture(nil,'ARTWORK');self.frostBeast=field:CreateTexture(nil,'BORDER')
 local messages=CreateFrame('Frame',nil,field);self.frostMessages=messages
 messages:SetSize(480,520);messages:SetPoint('TOPLEFT',0,0);messages:EnableMouse(false)
 messages:SetFrameLevel(field:GetFrameLevel()+2)
 self.frostNotice=UI.label(messages,'',12,-12,20);self.frostNotice:SetWidth(456);self.frostNotice:SetJustifyH('LEFT');self.frostNotice:SetTextColor(0.5,0.08,0.10)
 scene:Hide()
 local code=CreateFrame('Frame',nil,self.content,'BackdropTemplate');self.codePanel=code
 code:SetSize(386,210);code:SetPoint('TOPLEFT',25,-40);code:EnableMouse(true)
 code:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'});code:SetBackdropColor(0.035,0.055,0.08,1);UI.border(code)
 code:SetFrameLevel(self.content:GetFrameLevel()+20)
 UI.label(code,'Enter access code',24,-24,18)
 local input=CreateFrame('EditBox',nil,code,'InputBoxTemplate');self.codeInput=input
 input:SetSize(338,28);input:SetPoint('TOPLEFT',24,-68);input:SetAutoFocus(false);input:SetMaxLetters(64)
 self.codeFeedback=UI.label(code,'',24,-106,12);self.codeFeedback:SetWidth(338);self.codeFeedback:SetJustifyH('LEFT')
 self.codeSubmit=UI.button(code,'Unlock',24,-153,160,32,function() self:SubmitCode() end)
 self.codeCancel=UI.button(code,'Cancel',202,-153,160,32,function() self:CancelCode() end)
 input:SetScript('OnEnterPressed',function() self:SubmitCode() end)
 input:SetScript('OnEscapePressed',function() self:CancelCode() end)
 code:Hide()
 local oldKey=self.window:GetScript('OnKeyDown')
 self.window:SetScript('OnKeyDown',function(_,key)
  if combat() then self:Pause();self:Render();return end
  if self.screen=='game' and self.game and self.game.kind=='frost' then
   if not self.keyboardCaptured or self.paused then return end
   if key=='ESCAPE' or key=='P' then self:Pause();self:Render()
   elseif key=='R' then self:Start('frost')
   else
    if key=='SPACE' and not self.frostHeld[key] then S.jump(self.game) end
    self.frostHeld[key]=true;self:DeriveFrostKeys()
   end
  else oldKey(self.window,key) end
 end)
 self.window:SetScript('OnKeyUp',function(_,key)
  self.frostHeld[key]=nil;self:DeriveFrostKeys()
 end)
end
function A:DeriveFrostKeys()
 local h=self.frostHeld;local k=self.frostKeys
 k.left=h.A or h.LEFT;k.right=h.D or h.RIGHT;k.brake=h.S or h.DOWN
end
function A:Pause()
 base.Pause(self)
 if self.game and self.game.kind=='frost' then S.pause(self.game) end
 self.frostKeys={};self.frostHeld={}
 if self.codeOpen then
  self.codeOpen=false;self.codeInput:ClearFocus();self.codeInput:SetText('');self.codePanel:Hide()
 end
end
function A:OpenCode()
 if self.screen~='settings' or not self.window:IsShown() or combat() or self.db.frostUnlocked then return false end
 self:Pause();self.codeOpen=true;self.codeInput:SetText('');self.codeFeedback:SetText('');self:Render();self.codeInput:SetFocus();return true
end
function A:SubmitCode()
 if not self.codeOpen or not self.window:IsShown() or self.screen~='settings' or combat() then return false end
 if self.codeInput:GetText()~='ForTheHorde!' then
  self.codeFeedback:SetText('Incorrect code. Try again.');self.codeInput:SetText('');self.codeInput:SetFocus();return false
 end
 self.db.frostUnlocked=true;self.screen='lobby';self:CancelCode();return true
end
function A:CancelCode() self:Pause();if self.window:IsShown() then self:Render() end end
function A:Start(kind,level,rng)
 if kind~='frost' then return base.Start(self,kind,level,rng) end
 if not self.db.frostUnlocked then return false end
 self:Pause();if self.game and self.game.kind=='gems' then self.gemSession=self.game end
 self.game=S.new(freshSeed());self.game.kind='frost';self.frostVisual=V.new()
 self.screen='game';self.elapsed=0;self.resultGame=nil;self:Render();return true
end
function A:Resume()
 if not self.game or self.game.kind~='frost' then return base.Resume(self) end
 if self.screen~='game' or not self.window:IsShown() or self.game.status~='playing' or combat() then return false end
 self:Pause()
 if not pcall(self.window.SetPropagateKeyboardInput,self.window,false) then return false end
 local edit=ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
 if edit and ChatEdit_DeactivateChat then ChatEdit_DeactivateChat(edit) end
 self.game.paused=false;self.paused=false;self.keyboardCaptured=true;self.window:EnableKeyboard(true);return true
end
function A:RenderFrost()
 if self.game.status~='playing' and not self.paused then self:Pause() end
 if not self.frostArtLoaded then
  for _,t in ipairs(self.frostTerrain) do t:SetTexture(art..'terrain.tga') end
  for _,t in ipairs(self.frostDecor) do t:SetTexture(art..'decor.tga') end
  self.frostArtLoaded=true
 end
 local g=self.game;local pose,dx,dy,beastPose,bob=V.sample(self.frostVisual,g,self.frostKeys)
 local offset,first,second=V.terrain(g)
 cropTexture(self.frostTerrain[1],self.frostField,0,0,480,first,480,520,0,480/512,offset/1024,(offset+first)/1024)
 if second>0 then cropTexture(self.frostTerrain[2],self.frostField,0,first,480,second,480,520,0,480/512,0,second/1024) else self.frostTerrain[2]:Hide() end
 for side=1,2 do
  local x=side==1 and 4 or 532;local u=(side-1)/2
  cropTexture(self.frostDecor[side*2-1],self.frostScene,x,0,48,first,584,520,u,u+48/128,offset/1024,(offset+first)/1024)
  if second>0 then cropTexture(self.frostDecor[side*2],self.frostScene,x,first,48,second,584,520,u,u+48/128,0,second/1024) else self.frostDecor[side*2]:Hide() end
 end
 for i=1,48 do local o=g.objects[i];local t=self.frostPool[i]
  if o.active then t:SetAlpha(1);t:SetDrawLayer(g.jump<=0 and o.y>185 and 'OVERLAY' or 'BORDER');self:DrawFrostSprite(t,o.kind,o.x,o.y) else t:Hide() end
 end
 for i=1,6 do local gate=g.gates[i]
  for side=1,2 do local t=self.frostGates[i][side]
   if gate.active then t:SetDrawLayer(g.jump<=0 and gate.y>185 and 'OVERLAY' or 'BORDER');t:SetAlpha(gate.resolved and 0.4 or 1);self:DrawFrostSprite(t,side==1 and 'flagRed' or 'flagBlue',gate.x+(side==1 and -64 or 64),gate.y) else t:Hide() end
  end
 end
 self:DrawFrostSprite(self.frostSkier,pose,g.x+dx,185-S.jumpHeight(g)+dy)
 self.frostSkier:SetAlpha(g.inv>0 and (math.floor(g.time*8)%2==0 and 0.4 or 1) or 1)
 self.frostBeast:Hide()
 if g.monster=='chase' or g.monster=='lunge' then self:DrawFrostSprite(self.frostBeast,beastPose,g.monster=='lunge' and g.lane or g.mx,V.monsterY(g)+bob) end
 local message=''
 if g.status=='over' then message=g.message..string.format('\nDistance %dm + Bonus %d = %d\nClick Restart to try again',g.finalDistance,g.finalBonus,g.finalScore)
 elseif self.paused then message='PAUSED - keys released\nClick Ski to resume'
 elseif g.monster=='warning' then message='A GROWL UPHILL... '..math.ceil(g.mt)..'\nBuild speed!'
 elseif g.monster=='lunge' then message='LUNGE! CHANGE LANES!'
 elseif g.monster=='chase' then message='SNOW BEAST! Keep your speed!'
 elseif g.messageTime>0 then message=g.message
 elseif g.gateFlash>0 then message='CLEAN GATE +25 BONUS' end
 self.frostNotice:SetText(message)
 self.status:SetText(string.format('%dm   %d km/h   Hearts %d   Bonus %d',math.floor(g.distance),math.floor(g.speed*0.16),g.hp,g.bonus))
 self.pause.text:SetText(self.paused and 'Ski' or 'Pause');self.pause:SetShown(g.status=='playing')
end
function A:Render()
 local frost=self.screen=='game' and self.game and self.game.kind=='frost'
 -- Let the shared UI paint its navigation without traversing a grid board.
 local screen=self.screen
 if frost then self.screen='settings' end
 base.Render(self);self.screen=screen
 self.frostScene:SetShown(frost)
 self.frostCard:SetShown(screen=='lobby' and self.db.frostUnlocked and not self.codeOpen)
 if frost then
  for _,b in ipairs(self.options) do b:Hide() end
  self.scaleLabel:Hide();for _,b in ipairs(self.scaleButtons) do b:Hide() end
  self.title:SetText('Frost Run');self.title:ClearAllPoints();self.title:SetPoint('TOPLEFT',140,-84)
  self.hint:SetText('A/D or arrows: steer   S/Down: brake   Space: jump\nP/Escape: pause and release keys   R: new run')
  self.restart:Show();self.restart.text:SetText('Restart');self.back:Show()
  self:RenderFrost()
 end
 self.frostSecret:SetShown(screen=='settings' and not self.codeOpen)
 self.frostSecret:SetEnabled(not combat())
 self.codePanel:SetShown(self.codeOpen==true)
 if self.codeOpen then
  for _,b in ipairs(self.cards) do b:Hide() end
  self.settingsButton:Hide();self.hint:SetText('');self.title:SetText('Access code')
  for _,b in ipairs(self.options) do b:Hide() end
  self.scaleLabel:Hide();for _,b in ipairs(self.scaleButtons) do b:Hide() end
 else self.settingsButton:Show() end
end
function A:Tick(dt)
 if self.codeOpen and combat() then self:CancelCode();return end
 if not self.game or self.game.kind~='frost' then return base.Tick(self,dt) end
 if self.keyboardCaptured and combat() then self:Pause();self:Render();return end
 if self.paused or self.screen~='game' or not self.window:IsShown() or self.game.status~='playing' then return end
 S.update(self.game,self.frostKeys,dt)
 if self.game.status~='playing' then self:Pause() end
 self:RenderFrost()
end
