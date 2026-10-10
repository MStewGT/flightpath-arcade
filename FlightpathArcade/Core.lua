local A=FlightpathArcade
function A:FlightCheck()
 local flying=not not UnitOnTaxi('player')
 if flying==self.inFlight then return end
 self.inFlight=flying
 if flying then if self.db.autoOpen then self:Open() end
 else self:Pause(); if self.db.autoClose then self:Close() elseif self.window:IsShown() then self:Render() end end
end
function A:Initialize()
 if self.initialized then return end
 self.initialized=true
 FlightpathArcadeDB=type(FlightpathArcadeDB)=='table' and FlightpathArcadeDB or {}
 self.db=FlightpathArcadeDB
 for _,key in ipairs({'autoOpen','autoClose','minimap'}) do if type(self.db[key])~='boolean' then self.db[key]=true end end
 if type(self.db.uiScale)~='number' or self.db.uiScale~=self.db.uiScale then self.db.uiScale=1 end
 self.db.uiScale=math.max(0.75,math.min(1.5,self.db.uiScale))
 self:BuildUI(); self:FitWindow(true); self:UpdateMinimap(); self.inFlight=false; self:FlightCheck()
 SLASH_FLIGHTPATHARCADE1='/fpa'; SLASH_FLIGHTPATHARCADE2='/flightpatharcade'
 SlashCmdList.FLIGHTPATHARCADE=function(msg) if msg=='settings' then self.screen='settings'; self:Open() else self:Toggle() end end
 local interface=select(4,GetBuildInfo())
 if not interface or interface<16000 or interface>=17000 then print('|cffffcc55Flightpath Arcade:|r built for Forever 1.60.x; this client is unverified.') end
end
local events=CreateFrame('Frame'); A.events=events
for _,event in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_CONTROL_LOST','PLAYER_CONTROL_GAINED','PLAYER_REGEN_DISABLED','UI_SCALE_CHANGED','DISPLAY_SIZE_CHANGED'}) do pcall(events.RegisterEvent,events,event) end
events:SetScript('OnEvent',function(_,event)
 if event=='PLAYER_LOGIN' then A:Initialize()
 elseif A.initialized then
  if event=='UI_SCALE_CHANGED' or event=='DISPLAY_SIZE_CHANGED' then A:FitWindow(true); if A.window:IsShown() then A:Render() end
  elseif event=='PLAYER_REGEN_DISABLED' then A:Pause(); if A.window:IsShown() then A:Render() end
  else A:FlightCheck() end
 end
end)
-- One cheap state query twice a second, even while the arcade is hidden.
-- No game simulation or rendering happens on this observer.
local elapsed=0
events:SetScript('OnUpdate',function(_,dt) if not A.initialized then return end elapsed=elapsed+dt; if elapsed>=0.5 then elapsed=0; A:FlightCheck() end end)
