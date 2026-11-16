/* Fixed Helios input adapter and targeted Blueprint interactions.
 * Loaded by Lua on the game thread; all effects use original game functions.
 * The compiled adapter supports only the installed executable/runtime build. */
#include <windows.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "lua-rvas.h"
#include "runtime-identity.h"
typedef struct lua_State lua_State;
typedef int (*LuaFn)(lua_State*);
static long long (*toint)(lua_State*,int,int*);
static double (*tonum)(lua_State*,int,int*);
static void (*pushbool)(lua_State*,int);
static void (*pushint)(lua_State*,long long);
static const char* (*pushstr)(lua_State*,const char*);
static void (*pushfn)(lua_State*,LuaFn,int);
static void (*newtable)(lua_State*,int,int);
static void (*setfield)(lua_State*,int,const char*);
static int (*luaerr)(lua_State*,const char*,...);
static unsigned char *game;
static uintptr_t owner,player,pawn,primary,primary_pawn;
static DWORD game_thread;
/* XInput's fixed Windows ABI. TinyCC's SDK does not ship xinput.h. */
typedef struct {
 DWORD packet;
 WORD buttons;
 BYTE left_trigger, right_trigger;
 SHORT left_x, left_y, right_x, right_y;
} GamepadState;
typedef DWORD (WINAPI *GetGamepadState)(DWORD, GamepadState*);

static int read_gamepad(lua_State *L){
 static GetGamepadState get_state;
 static int initialized;
 int valid=0;
 long long slot=toint(L,1,&valid);
 if(!valid || slot<0 || slot>3)return luaerr(L,"Expected XInput slot from zero to three");
 if(!initialized){
  initialized=1;
  /* Helios imports XInput 1.3. Reuse that instance for Steam Input emulation. */
  HMODULE module=GetModuleHandleW(L"xinput1_3.dll");
  if(!module)module=LoadLibraryExW(L"xinput1_4.dll",NULL,0x00000800); /* System32 only. */
  if(!module)module=LoadLibraryExW(L"xinput9_1_0.dll",NULL,0x00000800);
  if(module)get_state=(GetGamepadState)GetProcAddress(module,"XInputGetState");
 }
 GamepadState state;
 if(!get_state || get_state((DWORD)slot,&state)!=ERROR_SUCCESS)return 0;
 pushint(L,state.left_x);pushint(L,state.left_y);
 pushint(L,state.buttons);pushint(L,state.left_trigger);pushint(L,state.right_trigger);
 pushint(L,state.right_x);pushint(L,state.right_y);
 return 7;
}
static int readable(uintptr_t p,size_t size){
 MEMORY_BASIC_INFORMATION m;
 return p>0x10000 && VirtualQuery((void*)p,&m,sizeof(m)) && m.State==MEM_COMMIT
  && !(m.Protect&(PAGE_NOACCESS|PAGE_GUARD)) && p+size>=p
  && p+size<=(uintptr_t)m.BaseAddress+m.RegionSize;
}
static int identity(unsigned char *base,unsigned long timestamp,unsigned long image_size){
 if(!base || !readable((uintptr_t)base,4096) || *(unsigned short*)base!=0x5a4d)return 0;
 unsigned long off=*(unsigned long*)(base+60);
 if(off>3500 || *(unsigned long*)(base+off)!=0x4550)return 0;
 return *(unsigned long*)(base+off+8)==timestamp && *(unsigned long*)(base+off+24+56)==image_size;
}
static int owns_second(void){
 if(!owner || owner==primary || !readable(owner,0x640) || !readable(player,0xc0)
  || !readable(pawn,0x680) || pawn==primary_pawn
  || *(uintptr_t*)(owner+0x290)!=player || *(int*)(player+0xb8)!=1
  || *(uintptr_t*)(owner+0x248)!=pawn || *(uintptr_t*)(pawn+0x250)!=owner)return 0;
 return 1;
}
static int checked(lua_State *L){
 if(GetCurrentThreadId()!=game_thread)return luaerr(L,"P2 native input must run on its bound game thread");
 if(!owns_second())
  return luaerr(L,"P2 native input ownership changed; bind the replacement pawn first");
 typedef void* (*ResolveWeak)(void*);
 void *board=((ResolveWeak)(game+0xee2420))((void*)(owner+0x634));
 if(!board || board!=(void*)*(uintptr_t*)(pawn+0x670))
  return luaerr(L,"P2 native input is not linked to its own chalkboard");
 return 1;
}
static int bind_owner(lua_State *L){
 int valid=0;
 uintptr_t values[5];
 for(int i=0;i<5;i++){values[i]=(uintptr_t)toint(L,i+1,&valid);if(!valid)return luaerr(L,"Expected five object addresses");}
 owner=values[0];player=values[1];pawn=values[2];primary=values[3];primary_pawn=values[4];
 game_thread=GetCurrentThreadId();checked(L);pushbool(L,1);return 1;
}
static int crouch(lua_State *L){
 checked(L);int valid=0;double value=tonum(L,1,&valid);
 if(!valid || !(value>=0.0 && value<=1.0))return luaerr(L,"Crouch amount must be between zero and one");
 typedef void (*Axis)(void*,float);
 ((Axis)(game+0xae0510))((void*)owner,(float)value);
 pushbool(L,1);return 1;
}
typedef void (*BlueprintNative)(void*,void*,void*);
static void *volatile *player_lookup;
static uintptr_t vent_graph,vent_actor;
static uintptr_t cage_graph;
static unsigned char *cage_code;
static unsigned int vent_reads,cage_reads;
typedef struct { uintptr_t actor; int target; } RouteEntry;
static RouteEntry *route_entries;
static size_t route_count,route_capacity;
static int route_enabled;
static int p2_interacting;

static int second_crossed_tripwire(uintptr_t level){
 /* The level's tripwire retains OtherActor in its persistent Blueprint frame. */
 if(!readable(level,0x3e0))return 0;
 uintptr_t wire=*(uintptr_t*)(level+0x3d8);
 if(!readable(wire,0x530))return 0;
 uintptr_t locals=*(uintptr_t*)(wire+0x528);
 return readable(locals,0x60) && *(uintptr_t*)(locals+0x58)==pawn;
}

static void interaction_player(void *context,void *stack,void *result){
 unsigned char *frame=stack;
 unsigned char *code=*(unsigned char**)(frame+0x20);
 ((BlueprintNative)(game+0xbe9e00))(context,stack,result);
 if(GetCurrentThreadId()!=game_thread)return;
 uintptr_t graph=*(uintptr_t*)(frame+0x10);
 uintptr_t actor=*(uintptr_t*)(frame+0x18);
 if(vent_actor && graph==vent_graph && actor==vent_actor && owns_second()){
  *(uintptr_t*)result=pawn;
  vent_reads++;
 }
 if(cage_graph && graph==cage_graph && code==cage_code &&
    owns_second() && second_crossed_tripwire(actor)){
  *(uintptr_t*)result=pawn;
  cage_reads++;
 }
 /* Generic route: Lua registers actors whose nearest player is P2. */
 if(route_enabled && owns_second()){
  for(size_t i=0;i<route_count;i++)
   if(route_entries[i].actor==actor && route_entries[i].target==1){
    *(uintptr_t*)result=pawn;
    break;
   }
 }
 /* P2 is actively grabbing something: level scripts should act on P2. */
 if(route_enabled && p2_interacting && owns_second()){
  *(uintptr_t*)result=pawn;
 }
}

static void release_player_lookup(void){
 if(!player_lookup || vent_actor || cage_graph || route_enabled)return;
 InterlockedCompareExchangePointer(player_lookup,game+0xbe9e00,(void*)interaction_player);
 player_lookup=NULL;
}

static void install_player_lookup(lua_State *L,uintptr_t lookup){
 if(!readable(lookup,0xc8))luaerr(L,"Invalid player lookup");
 void *volatile *native_fn=(void *volatile *)(lookup+0xc0); /* UFunction::Func */
 if(player_lookup==native_fn && *native_fn==(void*)interaction_player)return;
 if(player_lookup ||
    InterlockedCompareExchangePointer(native_fn,(void*)interaction_player,game+0xbe9e00)!=game+0xbe9e00)
  luaerr(L,"The player lookup already has a different native handler");
 player_lookup=native_fn;
}

static int route_vent(lua_State *L){
 int valid=0;
 uintptr_t lookup=(uintptr_t)toint(L,1,&valid);
 if(!valid)return luaerr(L,"Expected tunnel grate function address");
 if(GetCurrentThreadId()!=game_thread && game_thread)
  return luaerr(L,"The grate must be routed on its bound game thread");
 vent_graph=0;vent_actor=0;
 release_player_lookup();
 if(!lookup){pushint(L,vent_reads);vent_reads=0;return 1;}
 checked(L);
 uintptr_t graph=(uintptr_t)toint(L,2,&valid);
 if(!valid || !readable(graph,0xc8))return luaerr(L,"Invalid tunnel grate graph");
 uintptr_t actor=(uintptr_t)toint(L,3,&valid);
 if(!valid || !readable(actor,0x30))return luaerr(L,"Invalid tunnel grate object");
 install_player_lookup(L,lookup);
 vent_graph=graph;vent_actor=actor;vent_reads=0;
 return 0;
}

static int route_cage(lua_State *L){
 int valid=0;
 uintptr_t lookup=(uintptr_t)toint(L,1,&valid);
 if(!valid)return luaerr(L,"Expected cage player lookup address");
 if(GetCurrentThreadId()!=game_thread && game_thread)
  return luaerr(L,"The cage must be routed on its bound game thread");
 cage_graph=0;cage_code=NULL;
 release_player_lookup();
 if(!lookup){pushint(L,cage_reads);cage_reads=0;return 1;}
 checked(L);
 uintptr_t graph=(uintptr_t)toint(L,2,&valid);
 if(!valid || !readable(graph,0x68))return luaerr(L,"Invalid cage graph");
 /* UStruct::Script, then EX_CallMath, UFunction pointer and EX_EndFunctionParms. */
 unsigned char *script=*(unsigned char**)(graph+0x58);
 int length=*(int*)(graph+0x60);
 if(length!=3711 || !readable((uintptr_t)script,length) ||
    script[0x496]!=0x68 || script[0x49f]!=0x16)
  return luaerr(L,"The cage animation bytecode does not match");
 uintptr_t callee;
 memcpy(&callee,script+0x497,sizeof(callee));
 if(callee!=lookup)return luaerr(L,"The cage animation has a different player lookup");
 install_player_lookup(L,lookup);
 cage_graph=graph;
 cage_code=script+0x49f;
 cage_reads=0;
 return 0;
}

static int route_actor(lua_State *L){
 int valid=0;
 uintptr_t addr=(uintptr_t)toint(L,1,&valid);
 if(!valid || !addr)return luaerr(L,"Expected an actor address");
 long long target=toint(L,2,&valid);
 if(!valid || (target!=0 && target!=1))return luaerr(L,"Expected route target zero or one");
 if(game_thread && GetCurrentThreadId()!=game_thread)
  return luaerr(L,"Routing must run on the bound game thread");
 for(size_t i=0;i<route_count;i++)
  if(route_entries[i].actor==addr){route_entries[i].target=(int)target;return 0;}
 if(route_count==route_capacity){
  size_t capacity=route_capacity?route_capacity*2:64;
  RouteEntry *expanded=realloc(route_entries,capacity*sizeof(*expanded));
  if(!expanded)return luaerr(L,"Could not allocate route entries");
  route_entries=expanded;route_capacity=capacity;
 }
 route_entries[route_count].actor=addr;
 route_entries[route_count].target=(int)target;
 route_count++;
 return 0;
}

static int route_clear(lua_State *L){
 free(route_entries);route_entries=NULL;route_count=route_capacity=0;return 0;
}

static int set_interacting(lua_State *L){
 int valid=0;long long on=toint(L,1,&valid);
 if(!valid || (on!=0 && on!=1))return luaerr(L,"Expected interacting zero or one");
 p2_interacting=(int)on;
 return 0;
}

static int route_active(lua_State *L){
 int valid=0;long long on=toint(L,1,&valid);
 if(!valid || (on!=0 && on!=1))return luaerr(L,"Expected route active zero or one");
 if(on){
  if(game_thread && GetCurrentThreadId()!=game_thread)
   return luaerr(L,"The route must be installed on the bound game thread");
  uintptr_t lookup=(uintptr_t)toint(L,2,&valid);
  if(!valid)return luaerr(L,"Expected player lookup address");
  install_player_lookup(L,lookup);
  route_enabled=1;
 }else{
  route_enabled=0;
  free(route_entries);route_entries=NULL;route_count=route_capacity=0;
  release_player_lookup();
 }
 return 0;
}

/* Keep Helios in charge of the displayed view and isolate the hidden P2 view. */
typedef void (*CameraUpdate)(void*,float);
static void *volatile *camera_update_slot;
static uintptr_t first_view,second_view,dollhouse_class,zoom_tracks[2];
static float zoom_request,zoom_applied,original_fov,applied_fov,applied_time;
static int camera_mode;
static int fill_split_view;
typedef struct { uintptr_t view,controller; float time; unsigned char constrained; } AspectOverride;
static AspectOverride aspect_overrides[2];
/* Verified object dump: CameraCachePrivate 0x1a10 + POV 0x10 + flags 0x30, mask 1. */
static void restore_aspect(AspectOverride *saved){
 if(saved->view && readable(saved->view,0x1a51) && readable(saved->controller,0x2b8) &&
    *(uintptr_t*)(saved->controller+0x2b0)==saved->view &&
    *(uintptr_t*)(saved->view+0x218)==saved->controller &&
    *(float*)(saved->view+0x1a10)==saved->time){
  unsigned char *flags=(unsigned char*)(saved->view+0x1a50);
  *flags=(*flags&~1u)|saved->constrained;
 }
 saved->view=0;
}
static void apply_aspect(unsigned char *view,int index){
 if(!fill_split_view || camera_mode!=2 || !owns_second() || !readable((uintptr_t)view,0x1a51))return;
 AspectOverride *saved=&aspect_overrides[index];
 saved->view=(uintptr_t)view;
 saved->controller=*(uintptr_t*)(view+0x218);
 saved->time=*(float*)(view+0x1a10);
 saved->constrained=view[0x1a50]&1;
 view[0x1a50]&=~1u;
}
static int camera_fill(lua_State *L){
 int valid=0;long long enabled=toint(L,1,&valid);
 if(!valid || (enabled!=0 && enabled!=1))return luaerr(L,"Expected fill-screen zero or one");
 if(game_thread && GetCurrentThreadId()!=game_thread)return luaerr(L,"Camera fill must run on the game thread");
 fill_split_view=(int)enabled;
 if(!enabled){restore_aspect(&aspect_overrides[0]);restore_aspect(&aspect_overrides[1]);}
 return 0;
}
typedef struct {
 uint64_t weak;
 uintptr_t swapped;
 unsigned char first[5],second[5];
} SplitCameraActor;
static SplitCameraActor *split_actors;
static size_t split_count,split_capacity;
static int split_updating,split_clear_pending;

static void clear_split_actors(void){
 if(split_updating){split_clear_pending=1;return;}
 free(split_actors);
 split_actors=NULL;
 split_count=split_capacity=0;
 split_clear_pending=0;
}

static uintptr_t resolve_camera_actor(uint64_t *weak){
 typedef void* (*ResolveWeak)(void*);
 return (uintptr_t)((ResolveWeak)(game+0xee2420))(weak);
}

static void register_split_actor(lua_State *L,uintptr_t actor){
 typedef void (*AssignWeak)(void*,void*);
 uint64_t weak=0;
 ((AssignWeak)(game+0xedfcc0))(&weak,(void*)actor);
 for(size_t i=0;i<split_count;i++)if(split_actors[i].weak==weak)return;
 if(split_count==split_capacity){
  size_t capacity=split_capacity?split_capacity*2:64;
  SplitCameraActor *expanded=realloc(split_actors,capacity*sizeof(*expanded));
  if(!expanded){luaerr(L,"Could not allocate split camera blend states");return;}
  split_actors=expanded;
  split_capacity=capacity;
 }
 SplitCameraActor *entry=&split_actors[split_count++];
 memset(entry,0,sizeof(*entry));
 entry->weak=weak;
 /* Seed the secondary view from its current native tracks when split mode starts. */
 if(readable(second_view,0x26e4)){
  int count=*(int*)(second_view+0x26e0);
  uintptr_t list=*(uintptr_t*)(second_view+0x26d8);
  if(count>0 && count<=64 && readable(list,count*8))
   for(int i=0;i<count;i++)if(((uint64_t*)list)[i]==weak){
    float weight=1.0f/count;
    memcpy(entry->second,&weight,sizeof(weight));
    entry->second[4]=1;
    break;
   }
 }
}

static int split_camera_scan(lua_State *L){
 int valid=0;
 uintptr_t world=(uintptr_t)toint(L,1,&valid);
 if(!valid || !readable(world,0x158))return 0;
 uintptr_t blend_class=(uintptr_t)toint(L,2,&valid);
 if(!valid || GetCurrentThreadId()!=game_thread || camera_mode!=2 || split_updating)return 0;
 /* Use the world's loaded levels to include cameras owned by streamed sublevels. */
 uintptr_t levels=*(uintptr_t*)(world+0x148);
 int level_count=*(int*)(world+0x150);
 if(level_count<1 || level_count>1024 || !readable(levels,level_count*8))return 0;
 size_t retained=0;
 for(size_t i=0;i<split_count;i++)
  if(resolve_camera_actor(&split_actors[i].weak))split_actors[retained++]=split_actors[i];
 split_count=retained;
 /* FUObjectArray::ObjObjects and 64K-entry chunks of FUObjectItem. */
 unsigned char **chunks=*(unsigned char***)(game+0x3facb18);
 int objects=*(int*)(game+0x3facb2c);
 if(!chunks || objects<1 || objects>0x800000)return 0;
 for(int start=0;start<objects;start+=65536){
  unsigned char *item=chunks[start>>16];
  int end=objects-start<65536?objects-start:65536;
  if(!item)continue;
  for(int i=0;i<end;i++,item+=0x18){
   uintptr_t actor=*(uintptr_t*)item;
   if(!actor || (*(unsigned int*)(item+8)&0x30000000u))continue;
   uintptr_t type=*(uintptr_t*)(actor+0x10);
   if(type!=dollhouse_class && type!=blend_class)continue;
   uintptr_t level=*(uintptr_t*)(actor+0x20);
   for(int j=0;j<level_count;j++)
    if(((uintptr_t*)levels)[j]==level){register_split_actor(L,actor);break;}
  }
 }
 pushint(L,split_count);
 return 1;
}

static void update_split_camera(CameraUpdate update,void *view,float delta){
 if(split_updating){update(view,delta);return;}
 split_updating=1;
 for(size_t i=0;i<split_count;i++){
  SplitCameraActor *entry=&split_actors[i];
  entry->swapped=resolve_camera_actor(&entry->weak);
  if(!entry->swapped)continue;
  unsigned char *blend=(unsigned char*)(entry->swapped+0x2d0);
  memcpy(entry->first,blend,sizeof(entry->first));
  memcpy(blend,entry->second,sizeof(entry->second));
 }
 update(view,delta);
 for(size_t i=0;i<split_count;i++){
  SplitCameraActor *entry=&split_actors[i];
  if(!entry->swapped || resolve_camera_actor(&entry->weak)!=entry->swapped)continue;
  unsigned char *blend=(unsigned char*)(entry->swapped+0x2d0);
  memcpy(entry->second,blend,sizeof(entry->second));
  memcpy(blend,entry->first,sizeof(entry->first));
 }
 split_updating=0;
 if(split_clear_pending)clear_split_actors();
}

static int gameplay_view(unsigned char *view){
 return view && readable(primary,0x2b8) && readable((uintptr_t)view,0x2c52) &&
  *(uintptr_t*)(primary+0x248)==primary_pawn && *(uintptr_t*)(primary+0x2b0)==(uintptr_t)view &&
  *(uintptr_t*)(view+0x218)==primary && *(uintptr_t*)(view+0xe30)==primary_pawn &&
  !*(uintptr_t*)(view+0x1410) && !view[0x2b60] && !view[0x2c50] && !view[0x2c51];
}

static int follows_players(uintptr_t actor){
 if(!readable(actor,0x41c) || *(uintptr_t*)(actor+0x10)!=dollhouse_class ||
    !*(unsigned char*)(actor+0x22c) || !(*(float*)(actor+0x418)>.05f))return 0;
 uintptr_t volume=*(uintptr_t*)(actor+0x3c8);
 if(!volume)volume=*(uintptr_t*)(actor+0x3c0);
 if(!readable(volume,0x404))return 0;
 /* BoxComponent::GetScaledBoxExtent multiplies the box by ComponentToWorld.Scale3D. */
 float extent_x=*(float*)(volume+0x3f8) * *(float*)(volume+0x1e0);
 float extent_y=*(float*)(volume+0x3fc) * *(float*)(volume+0x1e4);
 return extent_x>=20 || extent_y>=20;
}

static int camera_tracks(unsigned char *view,uintptr_t tracks[2]){
 if(!gameplay_view(view) || (view[0x26a1]&4) || view[0x1a54])return 0;
 int count=*(int*)(view+0x26e0);
 uintptr_t list=*(uintptr_t*)(view+0x26d8);
 if(count<1 || count>2 || !readable(list,count*8))return 0;
 typedef void* (*ResolveWeak)(void*);
 for(int i=0;i<count;i++){
  tracks[i]=(uintptr_t)((ResolveWeak)(game+0xee2420))((void*)(list+i*8));
  if(!follows_players(tracks[i]))return 0;
 }
 return count;
}

static void restore_fov(void){
 if(zoom_applied>0 && readable(first_view,0x1a3c)){
  unsigned char *view=(unsigned char*)first_view;
  if(*(uintptr_t*)(view+0x218)==primary && *(float*)(view+0x1a10)==applied_time &&
     *(float*)(view+0x1a38)==applied_fov)
   *(float*)(view+0x1a38)=original_fov;
 }
 zoom_applied=0;
}

static void camera_update(void *camera,float delta){
 CameraUpdate update=(CameraUpdate)(game+0x52a750);
 if(GetCurrentThreadId()!=game_thread || !second_view){
  update(camera,delta);return;
 }
 unsigned char *view=camera;
 if((uintptr_t)view==second_view && owns_second() &&
    *(uintptr_t*)(owner+0x2b0)==second_view && *(uintptr_t*)(view+0x218)==owner){
  if(camera_mode==2){
   restore_aspect(&aspect_overrides[1]);
   update_split_camera(update,view,delta);
   apply_aspect(view,1);return;
  }
  if(gameplay_view((unsigned char*)first_view))update=(CameraUpdate)(game+0x2009190);
 }
 if((uintptr_t)view!=first_view){
  update(camera,delta);return;
 }
 restore_fov();
 restore_aspect(&aspect_overrides[0]);
 update(camera,delta);
 apply_aspect(view,0);
 if(zoom_request<=0 || !owns_second())return;
 uintptr_t tracks[2];
 int count=camera_tracks(view,tracks);
 int continuous=0;
 for(int i=0;i<count;i++)
  if(tracks[i]==zoom_tracks[0] || tracks[i]==zoom_tracks[1])continuous=1;
 if(!continuous)return;
 float fov=*(float*)(view+0x1a38);
 if(!(fov>20 && fov<80))return;
 const double half_rad=0.008726646259971648;
 double lens=tan(fov*half_rad);
 original_fov=fov;
 applied_fov=(float)(atan(lens*(1+zoom_request))/half_rad);
 if(applied_fov>80)applied_fov=80;
 applied_time=*(float*)(view+0x1a10);
 *(float*)(view+0x1a38)=applied_fov;
 zoom_applied=(float)(tan(applied_fov*half_rad)/lens-1);
}

static int replace_camera_update(void *volatile *slot,void *old_handler,void *new_handler){
 DWORD original,unused;
 if(!VirtualProtect((void*)slot,sizeof(*slot),PAGE_READWRITE,&original))return 0;
 void *previous=InterlockedCompareExchangePointer(slot,new_handler,old_handler);
 VirtualProtect((void*)slot,sizeof(*slot),original,&unused);
 return previous==old_handler;
}

static int shared_camera(lua_State *L){
 int valid=0;
 long long enabled=toint(L,1,&valid);
 if(!valid || enabled<0 || enabled>2)return luaerr(L,"Expected camera mode zero, one or two");
 if(game_thread && GetCurrentThreadId()!=game_thread)
  return luaerr(L,"The shared camera must run on the bound game thread");
 if(!enabled){
  restore_aspect(&aspect_overrides[0]);restore_aspect(&aspect_overrides[1]);
  restore_fov();
  first_view=second_view=dollhouse_class=zoom_tracks[0]=zoom_tracks[1]=0;
  zoom_request=0;
  camera_mode=0;
  clear_split_actors();
  if(camera_update_slot && replace_camera_update(camera_update_slot,(void*)camera_update,game+0x52a750))
   camera_update_slot=NULL;
  return 0;
 }
 checked(L);
 uintptr_t follow_class=(uintptr_t)toint(L,2,&valid);
 if(!valid || !readable(follow_class,0x28))return luaerr(L,"Expected Dollhouse camera class");
 if(!readable(primary,0x2b8))return luaerr(L,"The primary controller is unavailable");
 uintptr_t first_camera=*(uintptr_t*)(primary+0x2b0);
 uintptr_t second_camera=*(uintptr_t*)(owner+0x2b0);
 if(!readable(first_camera,0x220) || !readable(second_camera,0x220) ||
    first_camera==second_camera || *(uintptr_t*)(second_camera+0x218)!=owner)
  return luaerr(L,"The secondary camera is unavailable");
 uintptr_t table=*(uintptr_t*)second_camera;
 if(table!=*(uintptr_t*)first_camera || table!=(uintptr_t)(game+0x2cfd720))
  return luaerr(L,"Unexpected Helios camera vtable");
 void *volatile *slot=(void *volatile *)(table+0x700);
 if(camera_update_slot!=slot || *slot!=(void*)camera_update){
  if(!replace_camera_update(slot,game+0x52a750,(void*)camera_update))
   return luaerr(L,"The camera update already has a different handler");
  camera_update_slot=slot;
 }
 first_view=first_camera;
 second_view=second_camera;
 dollhouse_class=follow_class;
 camera_mode=(int)enabled;
 return 0;
}

static int camera_track(lua_State *L){
 if(!second_view || GetCurrentThreadId()!=game_thread || !owns_second())return 0;
 uintptr_t tracks[2]={0,0};
 if(!camera_tracks((unsigned char*)first_view,tracks))return 0;
 if(tracks[1] && tracks[1]<tracks[0]){
  uintptr_t first=tracks[0];tracks[0]=tracks[1];tracks[1]=first;
 }
 pushint(L,tracks[0]);
 pushint(L,(long long)(zoom_applied*10000+.5f));
 if(!tracks[1])return 2;
 pushint(L,tracks[1]);
 return 3;
}

static int camera_zoom(lua_State *L){
 int valid=0;
 double amount=tonum(L,1,&valid);
 if(!valid || !(amount>=0 && amount<=.46))return luaerr(L,"Invalid shared camera zoom");
 uintptr_t track=(uintptr_t)toint(L,2,&valid);
 if(!valid)return luaerr(L,"Expected camera track address");
 uintptr_t blend=(uintptr_t)toint(L,3,&valid);
 if(!valid)return luaerr(L,"Expected blended camera track address");
 if(GetCurrentThreadId()!=game_thread)return 0;
 zoom_request=track? (float)amount : 0;
 zoom_tracks[0]=track;
 zoom_tracks[1]=blend;
 if(zoom_request==0)restore_fov();
 return 0;
}

static int use_item(lua_State *L){
 checked(L);int valid=0;long long held=toint(L,1,&valid);
 if(!valid || (held!=0 && held!=1))return luaerr(L,"Expected use button state zero or one");
 typedef void (*Action)(void*);
 ((Action)(game+(held?0xae09e0:0xae0a70)))((void*)owner);
 pushbool(L,1);return 1;
}
static int jump(lua_State *L){
 checked(L);int valid=0;long long held=toint(L,1,&valid);
 if(!valid || (held!=0 && held!=1))return luaerr(L,"Expected jump button state zero or one");
 typedef void (*Action)(void*);
 /* Use the jump binding. P2's throw has its own input. */
 ((Action)(game+(held?0xadffa0:0xae0060)))((void*)owner);
 pushbool(L,1);return 1;
}
static int gadget(lua_State *L){
 checked(L);int valid=0;long long command=toint(L,1,&valid);
 if(!valid || command<0 || command>2)return luaerr(L,"Expected equipment input 0, 1 or 2");
 typedef void (*Action)(void*);
 /* Match EquipItem1, EquipItem2 and their shared release in Helios. */
 const unsigned long handlers[]={0xae4c40,0xafcae0,0xafcb30};
 ((Action)(game+handlers[command]))((void*)owner);
 if(command==2)((Action)(game+0xafcb80))((void*)owner);
 pushbool(L,1);return 1;
}
static int raw_move(lua_State *L){
 checked(L);int okx=0,oky=0,okw=0,okv=0;
 double x=tonum(L,1,&okx),y=tonum(L,2,&oky);
 double wx=tonum(L,3,&okw),wy=tonum(L,4,&okv);
 if(!okx || !oky || !okw || !okv || !(x>=-1 && x<=1 && y>=-1 && y<=1 && wx>=-1 && wx<=1 && wy>=-1 && wy<=1))return luaerr(L,"Expected normalized raw and world movement axes");
 /* This is Controller's local input, in addition to AIAnimator's world move.
  * Fixed keys are the four vector inputs written by ProcessPlayerInput. */
 /* Helios' raw vector is forward/right/up, not horizontal/vertical/up:
  * AxisLocomotionX adds (0,x,0), AxisLocomotionY adds (y,0,0). */
 float value[3]={(float)y,(float)x,0},world[3]={(float)wx,(float)wy,0};
 void *wrapper=(void*)*(uintptr_t*)(pawn+0x670);
 void *board=(void*)*(uintptr_t*)((unsigned char*)wrapper+0x28);
 typedef void (*SetVector)(void*,void*,const float*);
 ((SetVector)(game+0x9a05a0))(board,game+0x3eb7360,world);
 ((SetVector)(game+0x9a05a0))(board,game+0x3eb73c0,value);
 pushbool(L,1);return 1;
}
static int foreground(lua_State *L){
 DWORD process=0;GetWindowThreadProcessId(GetForegroundWindow(),&process);
 pushbool(L,process==GetCurrentProcessId());return 1;
}
/* Physical input remains observable while a rescue owns P1's controller tick. */
static int key_down(lua_State *L){
 int valid=0;long long key=toint(L,1,&valid);
 if(!valid || key<1 || key>254)return luaerr(L,"Expected Windows virtual key from 1 to 254");
 DWORD process=0;GetWindowThreadProcessId(GetForegroundWindow(),&process);
 pushbool(L,process==GetCurrentProcessId() && (GetAsyncKeyState((int)key)&0x8000)!=0);
 return 1;
}

/* Helios applies only the top input context. Recover P1's existing bindings
 * after travel without rerunning BeginPlay or clearing a live menu context. */
typedef struct { uintptr_t bindings; uint64_t weak_controller; } InputContext;
typedef struct { InputContext *entries; int count,capacity; } InputContextStack;
static int primary_input(lua_State *L){
 int valid=0;
 uintptr_t controller=(uintptr_t)toint(L,1,&valid);
 if(!valid || !readable(controller,0x620))return 0;
 uintptr_t second=(uintptr_t)toint(L,2,&valid);
 if(!valid || second==controller || !readable(second,0x620))second=0;
 if(second){
  uintptr_t second_local=*(uintptr_t*)(second+0x290);
  if(!readable(second_local,0xc0) || *(int*)(second_local+0xb8)!=1)second=0;
 }
 uintptr_t local=*(uintptr_t*)(controller+0x290);
 uintptr_t body=*(uintptr_t*)(controller+0x248);
 uintptr_t input=*(uintptr_t*)(controller+0xf8);
 if(!readable(local,0xc0) || *(int*)(local+0xb8)!=0 || !readable(body,0x258)
  || *(uintptr_t*)(body+0x250)!=controller || *(uintptr_t*)(controller+0x618)!=body
  || !readable(input,0x120))return 0;
 int actions=*(int*)(input+0x118),axes=*(int*)(input+0xd8);
 if(actions>0 && axes>0){pushint(L,0);return 1;}
 int source_actions=*(int*)(controller+0x570),source_axes=*(int*)(controller+0x580);
 if(source_actions<=0 || source_actions>256 || source_axes<=0 || source_axes>256)return 0;
 uintptr_t helios=(uintptr_t)((void* (*)(void))(game+0xb1c7f0))();
 if(!readable(helios,0x40))return 0;
 InputContextStack *stack=*(InputContextStack**)(helios+0x38);
 if(!readable((uintptr_t)stack,sizeof(*stack)) || stack->count<0 || stack->count>128
  || stack->capacity<stack->count)return 0;
 if(stack->count && !readable((uintptr_t)stack->entries,(size_t)stack->count*sizeof(InputContext)))return 0;
 int ours=-1;
 for(int i=stack->count-1;i>=0;--i){
  InputContext *entry=&stack->entries[i];
  void *live_controller=((void* (*)(void*))(game+0xee2420))(&entry->weak_controller);
  if(!live_controller)continue;
  if(second && (uintptr_t)live_controller==second && entry->bindings==second+0x568)continue;
  if((uintptr_t)live_controller!=controller || entry->bindings!=controller+0x568)return 0;
  ours=i;
  break;
 }
 while(stack->count>ours+1){
  InputContext discarded;
  int count=stack->count;
  ((void (*)(void*,void*))(game+0xb27280))(stack,&discarded);
  if(stack->count>=count)return 0;
 }
 if(ours>=0){
  ((void (*)(void*,int))(game+0xb11ee0))(stack,ours);
 }else{
  uint64_t weak=0;
  ((void (*)(void*,void*))(game+0xedfcc0))(&weak,(void*)controller);
  ((void (*)(void*,void*,uint64_t))(game+0xb27c70))(stack,(void*)(controller+0x568),weak);
 }
 input=*(uintptr_t*)(controller+0xf8);
 if(readable(input,0x120) && *(int*)(input+0x118)>0 && *(int*)(input+0xd8)>0){pushint(L,1);return 1;}
 return 0;
}
static int menu_pointer(lua_State *L){
 HWND window=GetForegroundWindow();
 DWORD process=0;
 POINT position;
 RECT client;
 CURSORINFO cursor={0};
 GetWindowThreadProcessId(window,&process);
 if(process!=GetCurrentProcessId() || !GetCursorPos(&position)
  || !ScreenToClient(window,&position) || !GetClientRect(window,&client))return 0;
 if(client.right<=0 || client.bottom<=0)return 0;
 cursor.cbSize=sizeof(cursor);
 pushint(L,position.x);pushint(L,position.y);
 pushint(L,client.right);pushint(L,client.bottom);
 pushbool(L,!GetCursorInfo(&cursor) || ((cursor.flags&CURSOR_SHOWING)!=0 && cursor.hCursor!=NULL));
 return 5;
}
int play_heartbeat_wave(double volume);
int stop_heartbeat_wave(void);
static int heartbeat(lua_State *L){
 int valid=0;
 double volume=tonum(L,1,&valid);
 if(!valid || !(volume>=0 && volume<=1))return luaerr(L,"Heartbeat volume must be between zero and one");
 pushbool(L,play_heartbeat_wave(volume));return 1;
}
static int stop_heartbeat(lua_State *L){
 pushbool(L,stop_heartbeat_wave());return 1;
}
static int key_ids(lua_State *L){
 const unsigned long offsets[]={0x3eb7360,0x3eb73c0,0x3eb73f0,0x3eb7420,0x3eb7ae0,0x3eb8920};
 for(int i=0;i<6;i++)pushint(L,*(unsigned int*)(game+offsets[i]+32));
 return 6;
}
static void field(lua_State *L,const char *name,LuaFn fn){pushfn(L,fn,0);setfield(L,-2,name);}
__declspec(dllexport) int luaopen_ln2_native(lua_State *L){
 unsigned char *runtime=(unsigned char*)GetModuleHandleW(L"UE4SS.dll");
 game=(unsigned char*)GetModuleHandleW(NULL);
 if(!identity(runtime,UE4SS_TIMESTAMP,UE4SS_IMAGE_SIZE))return 0;
 #define API(name,variable) variable=(void*)(runtime+RVA_##name)
 API(lua_tointegerx,toint);API(lua_tonumberx,tonum);API(lua_pushboolean,pushbool);
 API(lua_pushinteger,pushint);API(lua_pushstring,pushstr);API(lua_pushcclosure,pushfn);
 API(lua_createtable,newtable);API(lua_setfield,setfield);API(luaL_error,luaerr);
 if(!identity(game,GAME_TIMESTAMP,GAME_IMAGE_SIZE))return luaerr(L,"Unsupported Little Nightmares II build");
 const unsigned char signature[]={0x40,0x53,0x48,0x83,0xec,0x40,0x0f,0x29,0x74,0x24,0x30};
 if(memcmp(game+0xae0510,signature,sizeof(signature))!=0)return luaerr(L,"Native crouch signature does not match");
 newtable(L,0,23);
 field(L,"bind",bind_owner);field(L,"crouch",crouch);field(L,"use_item",use_item);
 field(L,"jump",jump);
 field(L,"vent",route_vent);
 field(L,"cage",route_cage);
 field(L,"route_actor",route_actor);
 field(L,"route_clear",route_clear);
 field(L,"route_active",route_active);
 field(L,"set_interacting",set_interacting);
 field(L,"shared_camera",shared_camera);
 field(L,"camera_tracks",camera_track);
 field(L,"split_camera_scan",split_camera_scan);
 field(L,"camera_zoom",camera_zoom);
 field(L,"camera_fill",camera_fill);
 field(L,"gadget",gadget);
 field(L,"raw_move",raw_move);field(L,"key_ids",key_ids);
 field(L,"foreground",foreground);
 field(L,"key_down",key_down);
 field(L,"primary_input",primary_input);
 field(L,"menu_pointer",menu_pointer);
 field(L,"gamepad",read_gamepad);
 field(L,"heartbeat",heartbeat);field(L,"stop_heartbeat",stop_heartbeat);
 pushstr(L,"Helios original / guarded P2 adapter with XInput");setfield(L,-2,"version");
 return 1;
}
