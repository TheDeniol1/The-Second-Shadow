local Six=require('six_appearance')
local previousFind,previousFName=StaticFindObject,FName
local skeleton={}
local monoPhysics={}
local monoMesh={Skeleton=skeleton,PhysicsAsset=monoPhysics}
local jumperPath='/Game/Characters/Six/SKM_Six_Jumper.SKM_Six_Jumper'
local raincoatPath='/Game/Characters/Six/SKM_Six.SKM_Six'
local jumper={Skeleton=skeleton,GetFullName=function()return jumperPath end}
local raincoat={Skeleton=skeleton,GetFullName=function()return raincoatPath end}
local shadow={}
local companion
local overseer={GetHeliosPlaypalPawn=function()return companion end}
local class={}
local component={SkeletalMesh=monoMesh,bVisible=true,VisibilityBasedAnimTickOption=1}
function component:K2_GetComponentLocation()return {} end
function component:K2_GetComponentRotation()return {} end
function component:SetVisibility(visible,propagate)
 assert(not propagate,'hiding the Mono renderer must leave attachments visible')
 self.bVisible=visible
end
StaticFindObject=function(path)
 if path==jumperPath then return jumper end
 if path==raincoatPath then return raincoat end
 if path:find('MAT_HologramGlitch_PhantomKids_Inst01',1,true) then return shadow end
 if path=='/Script/Helios.Default__OverseerBlueprintLibrary' then return overseer end
 assert(path=='/Script/Engine.SkeletalMeshActor')
 return class
end
FName=function(name)return name end

local actor,spawns,failAttach=nil,0,false
local world={}
function world:SpawnActor(kind)
 assert(kind==class,'create the native skeletal mesh actor')
 local visual={Mobility=0}
 function visual:SetMobility(mobility)self.Mobility=mobility end
 function visual:SetCollisionEnabled(mode)self.collision=mode end
 function visual:SetSkeletalMesh(mesh)self.SkeletalMesh=mesh end
 function visual:GetNumMaterials()return 2 end
 function visual:SetMaterial(index,value)
  self.materials=self.materials or {}
  self.materials[index]=value
 end
 function visual:SetMasterPoseComponent(master)self.master=master end
 function visual:K2_AttachToComponent(parent)
  assert(self.Mobility==2,'the visual mesh can follow a movable component')
  if failAttach then return false end
  self.parent=parent
  return true
 end
 function visual:GetAttachParent()return self.parent end
 actor={SkeletalMeshComponent=visual,bHidden=false}
 function actor:SetOwner(owner)self.owner=owner end
 function actor:SetActorEnableCollision(enabled)self.collision=enabled end
 function actor:SetActorHiddenInGame(hidden)self.bHidden=hidden end
 function actor:K2_DestroyActor()self.destroyed=true end
 spawns=spawns+1
 return actor
end

local p1={Pawn={}}
local p2={Player={ControllerId=1}}
local chapter='School'
local pawn={Mesh=component,Controller=p2,GetWorld=function()return world end,
 GetFullName=function()return '/Game/Levels/'..chapter..'/PLVL_'..chapter..'.BP_PlayerPawn_C'end}
p2.Pawn=pawn
local appearance=Six.new(function(value)return value~=nil and not value.destroyed end,
 function(a,b)return a~=nil and a==b end,function()end)
assert(not appearance:sync(p2,p1.Pawn,p1) and spawns==0,'the appearance only applies to the owned P2 pawn')
assert(appearance:sync(p2,pawn,p1) and actor.owner==pawn and actor.SkeletalMeshComponent.parent==component,'Six is attached to P2')
local visual=actor.SkeletalMeshComponent
assert(visual.SkeletalMesh==jumper and visual.materials[0]==shadow and visual.materials[1]==shadow,
 'without an active story companion P2 has the Dark Six silhouette and material')
assert(visual.master==component and visual.collision==0 and not actor.collision,
 'Six copies Mono poses without adding collision')
assert(component.SkeletalMesh==monoMesh and component.SkeletalMesh.PhysicsAsset==monoPhysics
 and not component.bVisible and component.VisibilityBasedAnimTickOption==0,
 'gameplay keeps the Mono mesh and physics and refreshes its hidden pose')
pawn.bHidden=true
appearance:syncVisibility()
assert(actor.bHidden,'Six follows checkpoint visibility')
pawn.bHidden=false
appearance:syncVisibility()
assert(not actor.bHidden,'Six becomes visible with P2')
local className='BP_SixPawn_C'
companion={Mesh={SkeletalMesh=jumper},GetWorld=pawn.GetWorld,IsAlive=function()return true end,
 GetClass=function()return {GetFullName=function()return className end} end}
assert(appearance:sync(p2,pawn,p1) and visual.SkeletalMesh==jumper and not visual.materials[0] and not visual.materials[1],
 'the real Six appearing restores jumper materials on the same visual actor')
companion.Mesh.SkeletalMesh=raincoat
assert(appearance:sync(p2,pawn,p1) and visual.SkeletalMesh==raincoat,'actual coat mesh selects the raincoat')
companion.Mesh=nil;className='BP_SixPawn_WithCoat_C'
assert(appearance:sync(p2,pawn,p1) and visual.SkeletalMesh==raincoat,'the coat class covers a muxed or temporarily unavailable mesh')
companion.bHidden=true
assert(appearance:sync(p2,pawn,p1) and visual.SkeletalMesh==raincoat,'a single missed sample leaves the current look')
assert(appearance:sync(p2,pawn,p1) and visual.SkeletalMesh==raincoat and visual.materials[0]==shadow,
 'sustained absence returns P2 to Dark Six with the last visible outfit')
assert(appearance:sync(p2,pawn,p1) and spawns==1,'sync keeps the existing visual actor')
appearance:restore()
assert(actor.destroyed and component.bVisible and component.VisibilityBasedAnimTickOption==1,
 'cleanup removes the visual actor and restores the original renderer')

assert(appearance:sync(p2,pawn,p1,true) and actor.SkeletalMeshComponent.SkeletalMesh==raincoat,
 'passing native control between Six and the shadow preserves the wardrobe')
appearance:restore()
companion=nil;chapter='Transmission';appearance:resetWardrobe()
local direct=Six.new(appearance.live,appearance.same,function()end)
assert(direct:sync(p2,pawn,p1,true) and actor.SkeletalMeshComponent.SkeletalMesh==raincoat
 and actor.SkeletalMeshComponent.materials[0]==shadow,'a direct load into Transmission selects the dark raincoat')
chapter='Wilderness';direct:resetWardrobe()
assert(direct:sync(p2,pawn,p1,true) and actor.SkeletalMeshComponent.SkeletalMesh==jumper
 and actor.SkeletalMeshComponent.materials[0]==shadow,'an earlier checkpoint restores the jumper silhouette')
direct:restore()
chapter='School'
local beforeFailure=spawns
jumper.Skeleton={}
assert(not appearance:sync(p2,pawn,p1) and spawns==beforeFailure,'incompatible skeleton does not create a visual actor')
jumper.Skeleton=skeleton
failAttach=true
assert(not appearance:sync(p2,pawn,p1) and actor.destroyed and component.bVisible,'failed attachment rolls back to Mono')
assert(not appearance:sync(p2,pawn,p1) and spawns==beforeFailure+1,'failed attachment is not retried for the same pawn')
StaticFindObject,FName=previousFind,previousFName
print('PASS: Six visual attachment, Dark Six wardrobe through handoff, direct chapter load, visibility and rollback.')
