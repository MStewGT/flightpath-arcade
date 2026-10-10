-- Regression coverage for Forever's modern-only chat API, using the shared UI mock.
return function(A,check,env)
 local original=ChatFrameUtil
 check(ChatEdit_GetActiveWindow==nil and ChatEdit_DeactivateChat==nil,'deprecated chat aliases absent')
 for _,kind in ipairs({'snake','frost'}) do
  local active,gets,deactivations
  local function prepare()
   env.combat(false);env.deny(false);A.db.frostUnlocked=true;A:Open();A:Start(kind)
   active=nil;gets=0;deactivations=0
   ChatFrameUtil={
    GetActiveWindow=function() gets=gets+1;return active end,
    DeactivateChat=function(edit)
     check(edit==active,'correct active chat edit box '..kind)
     check(A.paused and not A.keyboardCaptured and not A.window.keyboard,'release chat before capturing keys '..kind)
     edit.focus=false;active=nil;deactivations=deactivations+1
    end
   }
  end
  local function rejected(label)
   check(A:Resume()==false,'resume refused '..kind..' '..label)
   check(A.paused and not A.keyboardCaptured and not A.window.keyboard,'keys remain free '..kind..' '..label)
   if kind=='frost' then check(A.game.paused,'simulation remains paused '..label) end
  end
  prepare();check(A:Resume() and A.keyboardCaptured and A.window.keyboard,'modern-only no-chat capture '..kind)
  check(gets==1 and deactivations==0,'no active chat needs no deactivation '..kind)
  A:Pause();check(A.paused and not A.window.keyboard,'existing pause releases keys '..kind)
  prepare();local edit={focus=true};active=edit
  check(A:Resume() and A.keyboardCaptured and A.window.keyboard,'active-chat capture succeeds '..kind)
  check(not edit.focus and active==nil and gets==2 and deactivations==1,'chat focus released and verified '..kind)
  A:Close();check(A.paused and not A.window.keyboard,'close releases keys '..kind)
  prepare();ChatFrameUtil=nil;rejected('missing namespace')
  prepare();ChatFrameUtil={};rejected('missing helpers')
  prepare();ChatFrameUtil.GetActiveWindow=nil;rejected('missing getter')
  prepare();ChatFrameUtil.DeactivateChat=nil;rejected('missing deactivator')
  prepare();ChatFrameUtil.GetActiveWindow=true;rejected('invalid getter')
  prepare();ChatFrameUtil.GetActiveWindow=function() error('unavailable getter') end;rejected('getter error')
  prepare();active={focus=true};ChatFrameUtil.DeactivateChat=function() error('unavailable deactivator') end
  rejected('deactivator error');check(active.focus,'failed deactivation preserves chat '..kind)
  prepare();active={focus=true};ChatFrameUtil.DeactivateChat=function() end;rejected('chat still active')
  prepare();active={focus=true};local get=ChatFrameUtil.GetActiveWindow
  ChatFrameUtil.GetActiveWindow=function() if gets==1 then error('verification unavailable') end return get() end
  rejected('verification error')
  prepare();active={focus=true};env.combat(true);rejected('combat')
  check(gets==0 and deactivations==0 and active.focus,'combat leaves chat untouched '..kind)
  prepare();active={focus=true};env.deny(true);rejected('restricted propagation')
  check(gets==0 and deactivations==0 and active.focus,'rejected propagation leaves chat untouched '..kind)
  prepare();A:Close();rejected('hidden window');check(gets==0,'hidden resume never touches chat '..kind)
  prepare();A.screen='settings';rejected('settings screen');check(gets==0,'settings resume never touches chat '..kind)
  prepare();ChatFrameUtil=nil;rejected('temporary API loss')
  ChatFrameUtil=original;check(A:Resume() and A.keyboardCaptured,'retry after API recovery '..kind)
  A:Pause()
 end
 ChatFrameUtil=original;env.combat(false);env.deny(false)
end
