-- Pure Lua rules. No frames, timers, saved variables, or WoW API calls.
FlightpathArcade = FlightpathArcade or {}
local L = {}
FlightpathArcade.Logic = L
local function copy(a) local b={} for i=1,#a do b[i]=a[i] end return b end
local function shuffle(a,r) for i=#a,2,-1 do local j=r(i); a[i],a[j]=a[j],a[i] end end
local function neighbors(i,w,h,fn)
 local x,y=(i-1)%w,math.floor((i-1)/w)
 for dy=-1,1 do for dx=-1,1 do
  local nx,ny=x+dx,y+dy
  if (dx~=0 or dy~=0) and nx>=0 and nx<w and ny>=0 and ny<h then fn(ny*w+nx+1) end
 end end
end
function L.mines(r)
 return {kind='mines',w=8,h=8,bombs=10,board={},open={},flags={},status='playing',rng=r or math.random,score=0}
end
function L.reveal(s,i,flag)
 if s.status~='playing' or i<1 or i>64 or s.open[i] then return end
 if flag then s.flags[i]=not s.flags[i]; return end
 if s.flags[i] then return end
 if not s.started then
  local candidates={} local excluded={[i]=true}
  neighbors(i,8,8,function(j) excluded[j]=true end)
  for j=1,64 do s.board[j]=0; if not excluded[j] then candidates[#candidates+1]=j end end
  shuffle(candidates,s.rng)
  for j=1,s.bombs do s.board[candidates[j]]=-1 end
  for j=1,64 do if s.board[j]~=-1 then neighbors(j,8,8,function(k) if s.board[k]==-1 then s.board[j]=s.board[j]+1 end end) end end
  s.started=true
 end
 if s.board[i]==-1 then s.open[i]=true; s.status='lost'; return end
 local queue={i} local n=1
 while n<=#queue do
  local j=queue[n]; n=n+1
  if not s.open[j] and not s.flags[j] then
   s.open[j]=true; s.score=s.score+1
   if s.board[j]==0 then neighbors(j,8,8,function(k) if not s.open[k] then queue[#queue+1]=k end end) end
  end
 end
 if s.score==54 then s.status='won' end
end
function L.memory(r)
 local b={} for i=1,16 do b[i]=(i-1)%8+1 end shuffle(b,r or math.random)
 return {kind='memory',w=4,h=4,board=b,matched={},status='playing',score=0,moves=0}
end
function L.flip(s,i)
 if s.status~='playing' or s.matched[i] or s.second or s.first==i or not s.board[i] then return end
 if not s.first then s.first=i; return end
 s.moves=s.moves+1; s.second=i
 if s.board[i]==s.board[s.first] then
  s.matched[i]=true; s.matched[s.first]=true; s.score=s.score+1; s.first=nil; s.second=nil
  if s.score==8 then s.status='won' end
 else s.wait=0.8 end
end
function L.memoryTick(s,dt)
 if s.wait then s.wait=s.wait-dt; if s.wait<=0 then s.first=nil; s.second=nil; s.wait=nil end end
end
local dirs={UP={0,-1},DOWN={0,1},LEFT={-1,0},RIGHT={1,0}}
local function food(s)
 local free={} local occupied={} for _,i in ipairs(s.body) do occupied[i]=true end
 for i=1,s.w*s.h do if not occupied[i] then free[#free+1]=i end end
 if #free==0 then s.status='won'; s.food=nil else s.food=free[s.rng(#free)] end
end
function L.snake(r)
 local s={kind='snake',w=12,h=12,body={66,65,64},dir='RIGHT',nextDir='RIGHT',rng=r or math.random,score=0,status='playing'}
 food(s); return s
end
function L.turn(s,key)
 local d=dirs[key]; local current=dirs[s.dir]
 if d and not (d[1]==-current[1] and d[2]==-current[2]) then s.nextDir=key end
end
function L.snakeTick(s)
 if s.status~='playing' then return end
 s.dir=s.nextDir; local d=dirs[s.dir]; local head=s.body[1]
 local x,y=(head-1)%s.w+d[1],math.floor((head-1)/s.w)+d[2]
 if x<0 or x>=s.w or y<0 or y>=s.h then s.status='lost'; return end
 local nextHead=y*s.w+x+1; local eating=nextHead==s.food
 for j=1,#s.body-(eating and 0 or 1) do if s.body[j]==nextHead then s.status='lost'; return end end
 table.insert(s.body,1,nextHead)
 if eating then s.score=s.score+1; food(s) else table.remove(s.body) end
end
function L.matches(b)
 local found={}
 for y=0,5 do for x=0,5 do
  local i=y*6+x+1; local v=b[i]
  if v then
   if x<4 and v==b[i+1] and v==b[i+2] then found[i]=true; found[i+1]=true; found[i+2]=true end
   if y<4 and v==b[i+6] and v==b[i+12] then found[i]=true; found[i+6]=true; found[i+12]=true end
  end
 end end
 return found
end
local function adjacent(a,b) return math.abs(a-b)==6 or (math.floor((a-1)/6)==math.floor((b-1)/6) and math.abs(a-b)==1) end
function L.hasMove(b)
 for i=1,36 do for _,j in ipairs({i+1,i+6}) do if j<=36 and adjacent(i,j) then
  b[i],b[j]=b[j],b[i]; local yes=next(L.matches(b))~=nil; b[i],b[j]=b[j],b[i]
  if yes then return true end
 end end end return false
end
local function fresh(s)
 for attempt=1,100 do
  for i=1,36 do
   local choices={}
   for v=1,5 do
    if not ((i-1)%6>=2 and s.board[i-1]==v and s.board[i-2]==v) and not (i>12 and s.board[i-6]==v and s.board[i-12]==v) then choices[#choices+1]=v end
   end
   s.board[i]=choices[s.rng(#choices)]
  end
  if L.hasMove(s.board) then return end
 end
 -- Deterministic playable fallback even for pathological random generators.
 for i=1,36 do s.board[i]=((i-1)+math.floor((i-1)/6)*2)%5+1 end
 s.board[1]=1; s.board[2]=2; s.board[3]=1; s.board[8]=1
end
function L.gemLevel(level)
 if type(level)~='number' or level~=level then level=1 end
 level=math.max(1,math.min(10,math.floor(level)))
 return level,600+(level-1)*50,20
end
function L.gems(r,level)
 local normalized,target,moves=L.gemLevel(level)
 local s={kind='gems',w=6,h=6,board={},rng=r or math.random,status='playing',score=0,moves=moves,level=normalized,target=target}
 fresh(s); return s
end
function L.swap(s,a,b,record)
 if s.status~='playing' or not a or not b or not s.board[a] or not s.board[b] or not adjacent(a,b) then return false end
 s.board[a],s.board[b]=s.board[b],s.board[a]
 if not next(L.matches(s.board)) then s.board[a],s.board[b]=s.board[b],s.board[a]; return false end
 s.moves=s.moves-1
 for cascade=1,50 do
  local found=L.matches(s.board); if not next(found) then break end
  if record then record('highlight',s.board,{found=found,score=s.score}); record('clear',s.board,{found=found,score=s.score}) end
  for i in pairs(found) do s.board[i]=nil; s.score=s.score+10 end
  local origins={}
  for x=1,6 do
   local column={} local rows={}
   for y=5,0,-1 do local v=s.board[y*6+x]; if v then column[#column+1]=v; rows[#rows+1]=y end end
   for y=5,0,-1 do local k=6-y; s.board[y*6+x]=column[k] or s.rng(5); origins[y*6+x]=rows[k] or -(k-#column) end
  end
  if record then record('fall',s.board,{origins=origins,score=s.score}) end
 end
 if next(L.matches(s.board)) or not L.hasMove(s.board) then fresh(s); s.reshuffled=true; if record then record('refill',s.board,{score=s.score}) end end
 if s.score>=(s.target or 600) then s.status='won' elseif s.moves==0 then s.status='lost' end
 return true
end
