local TV=require('cinematic_tv')
local findObject,registerHook=StaticFindObject,RegisterHook
local hooks,plays={},{}
local now,moves,logs=0,0,0
local function actor(name,x,world)
 return {name=name,position={X=x,Y=0,Z=0},world=world or 1,
  GetFullName=function(self)return self.name end,
  K2_GetActorLocation=function(self)return self.position end}
end
local first=actor('BP_PlayerPawn_C /Game/Levels/PaleCity/PLVL_PaleCIty.Test',0)
local second=actor('P2',90)
local entry,exit,foreign=actor('TV A',0),actor('TV B',4600),actor('foreign TV',4600,2)
local supported,cleared,walking=true,true,true
local enabled,effectiveClip=true,nil
local lead,follower=first,second
local tv=TV.new({
 live=function(a)return a~=nil end,same=function(a,b)return a~=nil and a==b end,
 world=function(a,b)return a and b and a.world==b.world end,
 pair=function()return first,second,now end,
 enabled=function()return enabled end,log=function()logs=logs+1 end,
 canMove=function(p)return p==follower and not effectiveClip and cleared end,
 grounded=function(p)return p==lead and walking end,
 owns=function(p,clip)return p==follower and clip~=nil and effectiveClip==clip end,
 stop=function(p,clip)if p==follower and clip==effectiveClip then effectiveClip=nil end end,
 play=function(p,clip,screen,away)
  assert(p==follower)
  if clip=='ANIM_Player_TVStandReach' then assert(screen==entry.position and not away)
  else assert(clip=='ANIM_Player_TVExitGrounded' and screen==exit.position and away) end
  plays[#plays+1]=clip;effectiveClip=clip
  return clip,.8
 end,
 landing=function(p,q,at,accepts)
  assert(p==lead and q==follower and at==lead.position)
  local candidate={X=at.X+90,Y=0,Z=0}
  assert(not accepts({X=at.X+900,Y=0,Z=0}),'arrival cannot reach a different TV room')
  if supported and accepts(candidate) then return candidate end
 end,
 move=function(p,destination)
  assert(p==follower);p.position=destination;moves=moves+1;return true
 end,
})
local prefix='/Script/Helios.PuzzleTVActor:'
local child='/Game/GameplayLogic/AreaSpecific/TVs/PP_TV_Base.PP_TV_Base_C:'
local streaming=false
StaticFindObject=function(path)
 if path:find(prefix,1,true) or streaming then return {} end
end
RegisterHook=function(path,callback)assert(not hooks[path]);hooks[path]=callback end
local function ref(value)return {get=function()return value end}end
local function event(prefixPath,name,...)
 local params={...}
 for i=1,#params do params[i]=ref(params[i])end
 hooks[prefixPath..name](nil,table.unpack(params))
end
local function update(at,paused)
 now=at;return tv:update(first,second,now,paused)
end

tv:install(now)
assert(not hooks[child..'ReceivePawnEndTeleporting'],'the Blueprint class may still be streaming')
streaming=true;tv:install(.5);tv:install(1)
assert(hooks[child..'ReceivePawnEndTeleporting'],'retry after the Blueprint loads')
enabled=false
event(prefix,'ReceivePawnStartTeleporting',entry,first)
assert(not update(1) and #plays==0,'solo remains isolated')
enabled=true
event(prefix,'ReceivePawnStartTeleporting',entry,first)
event(child,'ReceivePawnStartTeleporting',entry,first)
assert(#plays==0,'native callbacks queue scene data without applying an animation')
assert(update(1.05) and tv:protectsSeparation() and #plays==1)
event(prefix,'ReceivePawnEndTeleporting',entry,exit,second)
event(prefix,'ReceivePawnEndTeleporting',entry,foreign,first)
event(prefix,'ReceivePawnEndTeleporting',exit,exit,first)
assert(update(1.1) and moves==0,'P2, another world and the same TV cannot close the route')
event(child,'ReceivePawnEndTeleporting',exit,entry,first)
event(prefix,'ReceivePawnEndTeleporting',entry,exit,first)
assert(not update(1.2) and moves==0,'exit callback must still wait for P1 to arrive near its target')
first.position={X=4640,Y=0,Z=0}
walking=false
assert(not update(1.4) and moves==0,'wait for P1 to find ground')
walking=true;supported=false
assert(not update(1.6) and moves==0,'a destination without support never moves P2')
supported=true;cleared=false
assert(not update(1.8) and moves==0,'wait for P2 to release a later action')
cleared=true
assert(update(2,true) == false and moves==0,'pause does not relocate P2')
assert(update(2.1) and moves==1 and second.position.X==4730 and #plays==2,'arrival plays a separate P2 exit pose')
local foreignPose='native foreign pose';effectiveClip=foreignPose
assert(not update(2.3) and not tv:protectsSeparation() and effectiveClip==foreignPose,'cleanup preserves a later native override')

first.position={X=0,Y=0,Z=0};second.position={X=90,Y=0,Z=0};effectiveClip=nil
event(child,'ReceivePawnTouchingScreen',entry,first)
assert(not update(3) and #plays==2,'a touch does not start a crossing on its own')
event(child,'ReceivePawnEndTeleporting',entry,exit,first)
first.position={X=4640,Y=0,Z=0}
assert(update(3.25) and moves==2 and #plays==3,'an exact end event can complete a route from the Blueprint touch')
tv:reset()
assert(not effectiveClip and not tv:protectsSeparation(),'reset releases only the owned exit')

first.position={X=0,Y=0,Z=0};second.position={X=90,Y=0,Z=0}
event(prefix,'ReceivePawnStartTeleporting',entry,first)
assert(update(4))
event(prefix,'ReceivePawnStartTeleporting',entry,second)
assert(not update(4.1) and moves==2 and effectiveClip=='ANIM_Player_TVStandReach',
 'P2 can reuse the same clip for a native trip without a stop from the companion route')
effectiveClip=nil
event(prefix,'ReceivePawnStartTeleporting',entry,first)
assert(update(4.2))
assert(not update(13) and moves==2 and not effectiveClip and not tv:protectsSeparation(),'missing arrivals release the scene and separation after a timeout')

lead,follower=second,first
first.position={X=90,Y=0,Z=0};second.position={X=0,Y=0,Z=0}
event(prefix,'ReceivePawnStartTeleporting',entry,second)
local locked,actorLocked=update(13.1)
assert(locked and actorLocked==first,'P1 accompanies P2 without owning P2 input')
event(child,'ReceivePawnEndTeleporting',exit,entry,second)
event(prefix,'ReceivePawnStartTeleporting',entry,second)
assert(not update(13.2) and moves==2,'duplicate start callbacks cannot overwrite a confirmed destination')
second.position={X=4640,Y=0,Z=0}
locked,actorLocked=update(13.4)
assert(locked and actorLocked==first and moves==3 and first.position.X==4730 and second.position.X==4640,
 'the original game chooses P2’s exit and only P1 is placed next to it')
tv:reset()
assert(not effectiveClip,'P1’s owned exit pose can be released')

first.position={X=90,Y=0,Z=0};second.position={X=0,Y=0,Z=0}
event(prefix,'ReceivePawnStartTeleporting',entry,second)
assert(update(14))
event(child,'ReceivePawnTouchingScreen',entry,first)
event(child,'ReceivePawnEndTeleporting',entry,exit,first)
event(child,'ReceivePawnEndTeleporting',entry,exit,second)
assert(not update(14.2) and moves==3 and effectiveClip=='ANIM_Player_TVStandReach',
 'both native trips survive when the companion only reports touch and exit')
effectiveClip=nil

event(child,'ReceivePawnTouchingScreen',entry,second)
assert(not update(15),'touch alone also leaves P2 in its original sequence')
event(child,'ReceivePawnEndTeleporting',entry,exit,second)
second.position={X=4640,Y=0,Z=0}
locked,actorLocked=update(15.1)
assert(locked and actorLocked==first and moves==4,'an exact exit can confirm the P2 route from a touch')
tv:reset()
StaticFindObject,RegisterHook=findObject,registerHook
print('PASS: TV traversal in both roles, independent native crossings, streaming, confirmed exits, pause and cleanup.')
