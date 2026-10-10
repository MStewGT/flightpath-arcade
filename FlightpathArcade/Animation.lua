-- Deterministic, bounded presentation timeline. Rules remain authoritative.
local L=FlightpathArcade.Logic
local function clone(b) local t={} for i=1,36 do t[i]=b[i] end return t end
local function phase(t,kind,board,duration,extra)
 local p=extra or {}; p.kind=kind; p.board=clone(board); p.duration=duration
 t[#t+1]=p; return p
end
function L.planSwap(s,a,b)
 if s.animation or s.status~='playing' or not a or not b or not s.board[a] or not s.board[b] then return false end
 if not (math.abs(a-b)==6 or math.floor((a-1)/6)==math.floor((b-1)/6) and math.abs(a-b)==1) then return false end
 local before=clone(s.board); local timeline={}
 phase(timeline,'swap',before,0.20,{a=a,b=b})
 -- Record the exact rule resolver, including its RNG order and bounded reshuffle.
 local valid=L.swap(s,a,b,function(kind,board,extra) phase(timeline,kind,board,kind=='highlight' and 0.18 or kind=='clear' and 0.16 or kind=='fall' and 0.32 or 0.22,extra) end)
 if not valid then
  local swapped=clone(before); swapped[a],swapped[b]=swapped[b],swapped[a]
  phase(timeline,'swap',swapped,0.20,{a=a,b=b})
 end
 s.animation={phases=timeline,index=1,time=0,score=valid and timeline[2].score or s.score,valid=valid}
 return true
end
function L.animationTick(s,dt)
 local anim=s.animation; if not anim then return false end
 anim.time=anim.time+math.max(0,dt)
 while anim.phases[anim.index] and anim.time>=anim.phases[anim.index].duration do
  anim.time=anim.time-anim.phases[anim.index].duration; anim.index=anim.index+1
 end
 if not anim.phases[anim.index] then s.animation=nil; return false end
 return true
end
