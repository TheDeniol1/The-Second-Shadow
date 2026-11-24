local Hoist=require('six_hoist')
local Binding=require('coop_bindings')
local preset=require('coop_input').presets[1]
local saved=Binding.new(preset,'bind.use=F4\nbind.call=M\n')
assert(saved.bindings.use=='F4' and saved.bindings.boost~='F4','migration keeps existing P2 bindings')
assert(not saved:assign('boost','F3'),'P1 boost key is reserved')
assert(saved:assign('boost','F5'))
assert(Binding.new(preset,saved:serialize()).bindings.boost=='F5','P2 boost rebind survives restart')

local function live(o)return type(o)=='table' end
local ready,helper,partner={SequenceLength=.6},{SequenceLength=1.25},{SequenceLength=1}
local motionHeight=240
local wall=false
local log={}
local originalFind=StaticFindObject
StaticFindObject=function(path)
 if path:find('HoistEnter',1,true) then return ready end
 if path:find('Six_HoistPlayerJump',1,true) then return helper end
 if path:find('Player_HoistPlayerJump',1,true) then return partner end
 if path:find('AnimationBlueprintLibrary',1,true) then
  return {ExtractRootMotion=function(_,asset,first,seconds,looping)
   assert(asset==partner and first==0 and not looping)
   return {Translation={X=12*seconds,Y=0,Z=motionHeight*math.min(seconds/.6,1)}}
  end}
 end
 return {CapsuleTraceSingleByProfile=function()return wall end}
end
local function pawn(x)
 local p={at={X=x,Y=0,Z=90},facing=1,alive=true}
 p.IsAlive=function(self)return self.alive end
 p.GetVelocity=function(self)return {X=0,Y=0,Z=self.speed or 0}end
 p.GetPlayerPickupInterface=function()return nil end
 p.K2_GetActorLocation=function(self)return self.at end
 p.GetActorForwardVector=function(self)return {X=self.facing,Y=0,Z=0}end
 p.K2_SetActorLocation=function(self,at,sweep)assert(sweep);self.at=at end
 p.LaunchCharacter=function(self,vel)self.launch=vel.Z end
 local anim={RootMotionMode=0,SetRootMotionMode=function(self,mode)self.RootMotionMode=mode end}
 p.Mesh={bPauseAnims=false,GetAnimInstance=function()return anim end,K2_GetComponentToWorld=function()return {}end}
 p.CapsuleComponent={GetScaledCapsuleHalfHeight=function()return 40 end,GetCollisionProfileName=function()return 'Pawn'end}
 p.CharacterMovement={MovementMode=1,GetGravityZ=function()return -980 end,StopMovementImmediately=function()end,
  SetMovementMode=function(self,mode)self.MovementMode=mode end}
 local control={IsPlayingOverrideAnimation=function(self)return self.mCurrentAnimStateAsset~=nil end}
 p.mAnimationControlComponent=control
 p.mAnimationOverrideComponent={
  PlayAnimationSequenceOverride2=function(_,asset)control.mCurrentAnimStateAsset=asset end,
  StopAnimationSequenceOverride=function()control.mCurrentAnimStateAsset=nil end}
 return p,anim
end
local p1,anim=pawn(60)
local p2=pawn(0)
local h=Hoist.new({live=live,same=function(a,b)return live(a) and a==b end,
 log=function(s)log[#log+1]=s end,math=function()return {TransformDirection=function(_,_,delta)return delta end}end})
local grabbing={true,false}
local controls={held={false,true},grab=function(role)return grabbing[role]end}
assert(h:update(p1,p2,controls,1,false,false) and h:blocks(p2) and not h:blocks(p1))
controls.held[2]=false
assert(h:update(p1,p2,controls,1.55,false,false) and not p1.launch and p2.Mesh.bPauseAnims)
grabbing[1]=false;h:update(p1,p2,controls,1.6,false,false)
grabbing[1]=true;wall=true
assert(h:update(p1,p2,controls,1.7,false,false) and not h.active.liftedAt,'wall blocks boost')
grabbing[1]=false;h:update(p1,p2,controls,1.8,false,false)
grabbing[1]=true;wall=false
assert(h:update(p1,p2,controls,2,false,false) and h:ownsPawn(p1) and h:ownsPawn(p2) and h:blocks(p1))
assert(not p2.Mesh.bPauseAnims and anim.RootMotionMode==1 and p1.CharacterMovement.MovementMode==5)
assert(h:update(p1,p2,controls,2.5,false,false) and math.abs(p1.at.Z-(90+350*.5/.6))<.01 and not p1.launch)
assert(h:update(p1,p2,controls,2.65,false,false) and math.abs(p1.at.Z-440)<.01 and anim.RootMotionMode==0)
assert(math.abs(p1.at.X-67.2)<.01,'boost height does not amplify horizontal motion')
assert(p1.CharacterMovement.MovementMode==3 and not h:blocks(p1) and h:blocks(p2)
 and not h:ownsPawn(p1) and h:ownsPawn(p2),'release the receiver at the apex, while the helper is still animating')
assert(not h:update(p1,p2,controls,3.3,false,false))

p1.at.Z=90;p1.facing=-1;p1.CharacterMovement.MovementMode=1
controls.held[1]=true
assert(h:update(p1,p2,controls,4,false,false) and h:blocks(p1) and not h:blocks(p2))
controls.held[1]=false;h:update(p1,p2,controls,4.3,false,false)
controls.held[1]=true
assert(not h:update(p1,p2,controls,4.5,false,false),'P1 can cancel with the fixed key')
controls.held[1]=false;h:update(p1,p2,controls,4.6,false,false)
controls.held[1]=true;h:update(p1,p2,controls,4.7,false,false)
motionHeight=0;grabbing[2]=true
assert(h:update(p1,p2,controls,5,false,false) and math.abs(p2.launch^2/(2*980)-350)<.01,
 'in-place clip uses physics to reach the same target height')
p2.speed=20
assert(h:update(p1,p2,controls,5.15,false,false) and h:blocks(p2))
p2.speed=-1
assert(h:update(p1,p2,controls,5.3,false,false) and not h:blocks(p2),'physics lift also releases when descent starts')
local scene={SequenceLength=2}
p1.mAnimationControlComponent.mCurrentAnimStateAsset=scene
assert(not h:update(p1,p2,controls,5.4,false,false))
assert(p1.mAnimationControlComponent.mCurrentAnimStateAsset==scene,'cancellation leaves a game-owned animation active')
assert(#log==2,'both directions triggered once')
StaticFindObject=originalFind
print('PASS: independent boost bindings, both roles, native root motion, pause, obstacles and scene cleanup.')
