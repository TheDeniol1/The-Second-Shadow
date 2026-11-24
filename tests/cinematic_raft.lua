local Raft=require('cinematic_raft')
local oldFind,oldName=StaticFindObject,FName
local firstAt,secondAt,deckAt={X=0,Y=0,Z=50},{X=90,Y=0,Z=50},{X=0,Y=0,Z=0}
local parent,worn,stopCount=nil,nil,0
local deck={K2_GetComponentLocation=function()return deckAt end}
local door={SKM_FloatingDoor02=deck}
local collision,shore={},{}
local seat={}
local moves,attachAllowed,moveAllowed=0,true,true
local root={
 GetAttachParent=function()return parent end,
 K2_AttachToComponent=function(_,target,_,position,rotation,scale,weld)
  assert(target==deck and position==1 and rotation==1 and scale==1 and not weld)
  if not attachAllowed then return false end
  parent=target;return true
 end,
}
local first={K2_GetActorLocation=function()return firstAt end,CharacterMovement={MovementMode=1}}
local second={RootComponent=root,K2_GetActorLocation=function()return secondAt end}
first.K2_GetActorRotation=function()return {Yaw=0}end
second.K2_GetActorRotation=first.K2_GetActorRotation
second.K2_SetActorLocationAndRotation=function(_,at)secondAt=at;moves=moves+1;return true end
second.K2_SetActorLocation=function(self,at)
 if not moveAllowed then return false end
 return self:K2_SetActorLocationAndRotation(at)
end
second.K2_DetachFromActor=function(_,p,r,s)
 assert(p==1 and r==1 and s==1)
 parent=nil
end
second.CharacterMovement={MovementMode=1,SetMovementMode=function(self,mode)self.MovementMode=mode end,
 StopMovementImmediately=function()end}
second.mAnimationControlComponent={IsPlayingOverrideAnimation=function()return worn~=nil end}
second.mAnimationOverrideComponent={PlayAnimationSequenceOverride2=function(_,clip,mode,loop)
 assert(clip==seat and mode==1 and loop)
 worn=clip
 second.mAnimationControlComponent.mCurrentAnimStateAsset=clip
end}

local support,clear=shore,true
local c={live=function(o)return o~=nil end,same=function(a,b)return a~=nil and a==b end,
 world=function(a,b)return a~=nil and b==first end,log=function()end,
 driver={pawn=second,stop=function()stopCount=stopCount+1 end},clear=function()return clear end,
 landing=function(p,q,at,accepts)
  assert(p==first and q==second and at==firstAt)
  local destination={X=at.X+100,Y=at.Y,Z=at.Z}
  local hit={Component={Get=function()return {GetOwner=function()return support end}end}}
  if accepts(destination,{HitResult=hit}) then return destination end
 end}
StaticFindObject=function(path)
 if path:find('BP_FloatingDoor02_2',1,true) then return door end
 if path:find('RaftCollision',1,true) then return collision end
end
FName=function(value)return value end
local s={p=first,q=second,key='door ride',now=0}
local canBoard=true
local function start()
 local ride=assert(Raft.start(c,s,seat,function(p)assert(p==second);return canBoard end))
 ride.key=s.key
 return ride
end
assert(start().passThrough and moves==0 and stopCount==0,'shore does not count as a seat and P2 keeps input')
support=collision;clear=false
assert(start().passThrough and not parent and moves==0,'a blocked boarding path cannot move P2')
clear=true;attachAllowed=false
local from=secondAt
assert(start().passThrough and not parent and secondAt==from and second.CharacterMovement.MovementMode==1,
 'failed attachment restores the original position and leaves physics active')
attachAllowed=true
local ride=start()
assert(parent==deck and worn==seat and second.CharacterMovement.MovementMode==0,'P2 rides with an independent seated animation')
assert(Raft.tick(c,ride,s),'keep the occupied seat while the native timeline plays')
s.key=nil;s.now=10
assert(Raft.tick(c,ride,s) and parent==deck,'wait if near ground still belongs to the raft')
support=shore;firstAt={X=700,Y=100,Z=90};s.now=10.3
moveAllowed=false
assert(Raft.tick(c,ride,s) and parent==deck and second.CharacterMovement.MovementMode==0,
 'a failed shore placement keeps P2 seated and can be retried')
moveAllowed=true;s.now=10.6
assert(not Raft.tick(c,ride,s) and not parent and secondAt.X==800 and second.CharacterMovement.MovementMode==3,
 'disembark onto valid shore next to P1 and restore physics')

firstAt,secondAt={X=0,Y=0,Z=50},{X=90,Y=0,Z=50}
second.CharacterMovement.MovementMode=1
support=door
s.key='door ride';ride=start()
local foreign={}
parent=foreign
Raft.release(c,ride)
assert(parent==foreign,'cleanup leaves a later attachment in place')
parent=nil
Raft.release(c,ride)
assert(second.CharacterMovement.MovementMode==3,'cleanup restores physics even after the deck unloads')

firstAt,secondAt={X=0,Y=0,Z=50},{X=470,Y=0,Z=50}
second.CharacterMovement.MovementMode=1
worn=nil;s.now=11
local oldMoves=moves
ride=start()
assert(ride.passThrough and not ride.asset and moves==oldMoves,'a late player can approach under normal control')
secondAt={X=100,Y=0,Z=50};canBoard=false;s.now=11.3
assert(Raft.tick(c,ride,s) and ride.passThrough and moves==oldMoves,'a later conflicting action keeps the seat free')
canBoard=true;s.now=11.6
assert(Raft.tick(c,ride,s) and not ride.passThrough and ride.protectsSeparation and parent==deck and moves==oldMoves+1,
 'the late player can board after walking into reach of the real moving deck')
Raft.release(c,ride)

worn=nil;second.CharacterMovement.MovementMode=1
clear=false;s.now=12
ride=start()
parent=deck
Raft.release(c,ride)
assert(parent==deck and second.CharacterMovement.MovementMode==1,'a pending companion route never detaches a native attachment')
parent=nil;s.key=nil;s.now=12.3;clear=true
oldMoves=moves
assert(not Raft.tick(c,ride,s) and moves==oldMoves,'a finished native timeline cannot board a late player')
StaticFindObject,FName=oldFind,oldName
print('PASS: raft boarding at both arrival times, ownership, failed landing retry and safe cleanup.')
