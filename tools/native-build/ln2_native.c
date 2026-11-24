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
static int (*gettop)(lua_State*);
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
static void clear_school_escort(void);
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
 if(owner!=values[0] || pawn!=values[2] || primary_pawn!=values[4])clear_school_escort();
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
static int six_crouch(lua_State *L){
 if(GetCurrentThreadId()!=game_thread)return luaerr(L,"Six input must run on the bound game thread");
 int valid=0;
 uintptr_t six=(uintptr_t)toint(L,1,&valid);
 if(!valid)return luaerr(L,"Expected Six's pawn address");
 uintptr_t animator=(uintptr_t)toint(L,2,&valid);
 if(!valid)return luaerr(L,"Expected Six's animator address");
 long long held=toint(L,3,&valid);
 if(!valid || (held!=0 && held!=1))return luaerr(L,"Expected a crouch button state");
 /* A release can accompany a controller replacement. Verify the old Six and
  * her animator before clearing input, even if the spare local pawn is gone. */
 if((held && !owns_second()) || six==pawn || six==primary_pawn
  || !readable(six,0x678) || !readable(animator,0x100) || *(uintptr_t*)(animator+0xf8)!=six){
  pushbool(L,0);return 1;
 }
 uintptr_t controller=*(uintptr_t*)(six+0x250);
 uintptr_t wrapper=*(uintptr_t*)(six+0x670);
 if(controller==owner || controller==primary || !readable(controller,0x2b0) || !readable(wrapper,0x30)
  || *(uintptr_t*)(controller+0x248)!=six || *(uintptr_t*)(controller+0x2a8)!=animator){
  pushbool(L,0);return 1;
 }
 uintptr_t board=*(uintptr_t*)(wrapper+0x28);
 if(!readable(board,0x1c0)){pushbool(L,0);return 1;}
 /* AxisCrouch and SneakComponent both write this float to the pawn's chalkboard. */
 const float amount=held ? 1.0f : 0.0f;
 typedef void (*SetFloat)(void*,const void*,const float*);
 ((SetFloat)(game+0x99ea90))((void*)board,game+0x3eb7ae0,&amount);
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
static int frame_rule_enabled;
static unsigned int frame_rule_reads;
static uintptr_t box_pawn,box_primary;
static DWORD box_route_tick;
static unsigned int box_route_reads;

enum { weapon_dispatch_call=0xa5fe6f, multicast_dispatch=0x53b370, max_hit_receivers=32 };
typedef struct {
 uintptr_t instigator, actor;
 uintptr_t receivers[max_hit_receivers];
 size_t count;
} WeaponHit;
static const WeaponHit *weapon_hit;
static unsigned char *weapon_dispatch_bridge;
static unsigned int weapon_hit_reads;

static void dispatch_weapon_hit(void *delegate,void *params){
 typedef void (*Dispatch)(void*,void*);
 Dispatch dispatch=(Dispatch)(game+multicast_dispatch);
 if(GetCurrentThreadId()!=game_thread || !route_enabled){
  dispatch(delegate,params);
  return;
 }

 /* DamageReciever::mOnWeaponHit is at 0xb0. Its first parameter is Instigator.
  * Capture the component owner and the live recipients of this exact event. */
 WeaponHit hit={0};
 const WeaponHit *previous=weapon_hit;
 uintptr_t receiver=(uintptr_t)delegate-0xb0;
 if(readable((uintptr_t)params,sizeof(uintptr_t)))hit.instigator=*(uintptr_t*)params;
 if(readable(receiver,0xc0)){
  hit.actor=*(uintptr_t*)(receiver+0xa0); /* UActorComponent::GetOwner. */
  uintptr_t list=*(uintptr_t*)delegate;
  int count=*(int*)((unsigned char*)delegate+8);
  if(count>0 && count<=max_hit_receivers && readable(list,(size_t)count*16)){
   typedef void* (*ResolveWeak)(void*);
   for(int i=0;i<count;i++){
    uintptr_t target=(uintptr_t)((ResolveWeak)(game+0xee2420))((void*)(list+(size_t)i*16));
    if(target)hit.receivers[hit.count++]=target;
   }
  }
 }
 weapon_hit=&hit;
 dispatch(delegate,params);
 weapon_hit=previous;
}

static int hit_recipient(const WeaponHit *hit,uintptr_t actor){
 if(!actor)return 0;
 if(hit->actor==actor)return 1;
 for(size_t i=0;i<hit->count;i++)if(hit->receivers[i]==actor)return 1;
 return 0;
}

static int install_relative_call(unsigned long site,unsigned long original_offset,
 const unsigned char *expected,size_t length,uintptr_t wrapper,unsigned char **installed){
 if(*installed)return 1;
 unsigned char *call=game+site;
 if(((uintptr_t)(call+1)&3) || !readable((uintptr_t)call,length) || memcmp(call,expected,length)!=0)return 0;

 /* The original five-byte call can reach only a nearby destination. Keep the
  * bridge separate from game code and make it executable after writing it. */
 SYSTEM_INFO info;
 GetSystemInfo(&info);
 uintptr_t step=info.dwAllocationGranularity;
 uintptr_t base=(uintptr_t)call & ~(step-1);
 unsigned char *bridge=NULL;
 for(uintptr_t delta=step;delta<0x7fff0000 && !bridge;delta+=step){
  if(base>delta)bridge=VirtualAlloc((void*)(base-delta),16,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE);
  if(!bridge)bridge=VirtualAlloc((void*)(base+delta),16,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE);
 }
 if(!bridge)return 0;
 const unsigned char start[]={0x48,0xb8}; /* mov rax, wrapper; jmp rax */
 const unsigned char finish[]={0xff,0xe0};
 memcpy(bridge,start,sizeof(start));
 memcpy(bridge+2,&wrapper,sizeof(wrapper));
 memcpy(bridge+10,finish,sizeof(finish));

 DWORD old,unused;
 HMODULE pinned;
 if(!VirtualProtect(bridge,16,PAGE_EXECUTE_READ,&old) ||
    !FlushInstructionCache(GetCurrentProcess(),bridge,12) ||
    !GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_PIN,
                        (LPCWSTR)wrapper,&pinned) ||
    !VirtualProtect(call,5,PAGE_EXECUTE_READWRITE,&old)){
  VirtualFree(bridge,0,MEM_RELEASE);
  return 0;
 }
 /* The immediate operand is aligned in this build. Leave another mod's
  * replacement alone if the target changed after the signature check. */
 LONG relative=(LONG)((intptr_t)bridge-(intptr_t)(call+5));
 LONG original=(LONG)(original_offset-site-5);
 if(InterlockedCompareExchange((volatile LONG*)(call+1),relative,original)!=original){
  VirtualProtect(call,5,old,&unused);
  VirtualFree(bridge,0,MEM_RELEASE);
  return 0;
 }
 FlushInstructionCache(GetCurrentProcess(),call,5);
 VirtualProtect(call,5,old,&unused);
 *installed=bridge;
 return 1;
}

static int install_weapon_dispatch(void){
 const unsigned char expected[]={0xe8,0xfc,0xb4,0xad,0xff,0x48,0x83,0xc4,0x58,0xc3};
 return install_relative_call(weapon_dispatch_call,multicast_dispatch,expected,sizeof(expected),
  (uintptr_t)dispatch_weapon_hit,&weapon_dispatch_bridge);
}

enum { school_perception_call=0x9c4f93, ignore_stimulus=0x9c2a00, max_school_observers=48 };
static unsigned char *school_perception_bridge;
static uintptr_t school_pawn,school_observers[max_school_observers];
static int school_count;
static unsigned int school_reads;
static void clear_school_escort(void){school_pawn=0;school_count=0;}

static int protected_stimulus(void *analyzer,void *owned_stimulus){
 if(!school_pawn || GetCurrentThreadId()!=game_thread || !owns_second())return 0;
 int i=0;
 while(i<school_count && school_observers[i]!=(uintptr_t)analyzer)i++;
 if(i==school_count || !readable((uintptr_t)owned_stimulus,sizeof(uintptr_t)))return 0;
 uintptr_t stimulus=*(uintptr_t*)owned_stimulus;
 if(!readable(stimulus,0x90))return 0;
 typedef void* (*ResolveWeak)(void*);
 ResolveWeak resolve=(ResolveWeak)(game+0xee2420);
 uintptr_t actor=(uintptr_t)resolve((void*)(stimulus+0x80));
 if(actor && actor!=school_pawn)return 0;
 /* The secondary weak reference is PawnPropertiesComponent, not a pawn. */
 uintptr_t properties=(uintptr_t)resolve((void*)(stimulus+0x88));
 if(properties)
  return readable(school_pawn,0x680) && *(uintptr_t*)(school_pawn+0x678)==properties;
 return actor==school_pawn;
}

static unsigned char school_ignore_stimulus(void *analyzer,void *owned_stimulus){
 int escorted=protected_stimulus(analyzer,owned_stimulus);
 typedef unsigned char (*IgnoreStimulus)(void*,void*);
 /* The original consumes the reference passed by the caller. Run it even
  * when an escort overrides the result. */
 unsigned char ignored=((IgnoreStimulus)(game+ignore_stimulus))(analyzer,owned_stimulus);
 if(escorted && !ignored)school_reads++;
 return ignored || escorted;
}

static int school_escort(lua_State *L){
 if(GetCurrentThreadId()!=game_thread)return luaerr(L,"School escort must run on the bound game thread");
 int valid=0;
 uintptr_t companion=(uintptr_t)toint(L,1,&valid);
 if(!valid)return luaerr(L,"Expected escorted pawn address");
 if(!companion){clear_school_escort();return 0;}
 int count=gettop(L)-1;
 if(!owns_second() || companion==primary_pawn || !readable(companion,0x680)
  || count<1 || count>max_school_observers)return luaerr(L,"Invalid school escort context");
 uintptr_t observers[max_school_observers];
 for(int i=0;i<count;i++){
  observers[i]=(uintptr_t)toint(L,i+2,&valid);
  if(!valid || !readable(observers[i],0xf0))return luaerr(L,"Invalid school observer");
 }
 const unsigned char expected[]={0xe8,0x68,0xda,0xff,0xff,0x48,0x8b,0x5f,0x08,0x84,0xc0};
 if(!install_relative_call(school_perception_call,ignore_stimulus,expected,sizeof(expected),
     (uintptr_t)school_ignore_stimulus,&school_perception_bridge))
  return luaerr(L,"The school perception call does not match the supported build");
 memcpy(school_observers,observers,(size_t)count*sizeof(uintptr_t));
 school_pawn=companion;
 school_count=count;
 return 0;
}

static int school_escort_reads(lua_State *L){pushint(L,school_reads);return 1;}

static int second_crossed_tripwire(uintptr_t level){
 /* The level's tripwire retains OtherActor in its persistent Blueprint frame. */
 if(!readable(level,0x3e0))return 0;
 uintptr_t wire=*(uintptr_t*)(level+0x3d8);
 if(!readable(wire,0x530))return 0;
 uintptr_t locals=*(uintptr_t*)(wire+0x528);
 return readable(locals,0x60) && *(uintptr_t*)(locals+0x58)==pawn;
}


/* Bounds of the calling thread's stack (Windows 8 and later). Only the game
 * thread calls it, and only from Blueprint lookups. */
static void thread_stack_bounds(uintptr_t *low,uintptr_t *high){
 typedef void (WINAPI *Limits)(PULONG_PTR,PULONG_PTR);
 static Limits limits;
 static int resolved;
 if(!resolved){
  HMODULE kernel=GetModuleHandleA("kernel32.dll");
  limits=kernel?(Limits)GetProcAddress(kernel,"GetCurrentThreadStackLimits"):NULL;
  resolved=1;
 }
 *low=*high=0;
 if(limits){ULONG_PTR l=0,h=0;limits(&l,&h);*low=(uintptr_t)l;*high=(uintptr_t)h;}
}

/* Event subject observation (phase 0). Read only: it records which player the
 * calling Blueprint frames refer to, without changing the lookup result.
 * FFrame layout confirmed in UObject::ProcessEvent of this build (0xecddc3):
 * Node 0x10, Object 0x18, Code 0x20, Locals 0x28, PreviousFrame 0x70.
 * UStruct::PropertiesSize is 0x50 and Script 0x58 in the same function. */
enum { frame_node=0x10, frame_object=0x18, frame_locals=0x28, frame_previous=0x70,
 struct_properties_size=0x50, struct_script=0x58, subject_scan_bytes=4096, subject_depth=4,
 subject_slots=1024, subject_limit=768 };
enum { verdict_none, verdict_p1, verdict_p2, verdict_both, verdict_self1, verdict_self2, verdict_count };
typedef struct {
 uintptr_t graph,actor;
 unsigned int counts[verdict_count];
 unsigned int routed;
 unsigned int grabs[2];
 int depth;
 int offsets[2];
 long code;
 int dirty;
} SubjectEntry;
static SubjectEntry subject_entries[subject_slots];
static size_t subject_count,subject_cursor;
static unsigned int subject_dropped;
static int subject_enabled;
static uintptr_t subject_grab[2];

/* Slots where a player lookup has left its answer. Persistent Ubergraph
 * frames keep those answers (P1) next to fresh event parameters, so a frame
 * that stored an old answer must not count as naming P1. */
enum { return_slot_capacity=1024 };
typedef struct { uintptr_t node; int offset; } ReturnSlot;
static ReturnSlot return_slots[return_slot_capacity];
static unsigned int return_slot_count;

static size_t return_slot_hash(uintptr_t node,int offset){
 return (size_t)(((node>>4)*0x9e3779b97f4a7c15ULL)^((uint64_t)(unsigned)offset*0xc2b2ae3d27d4eb4fULL))%return_slot_capacity;
}

static int return_slot_known(uintptr_t node,int offset){
 if(!node || !return_slot_count)return 0;
 size_t i=return_slot_hash(node,offset);
 for(size_t probe=0;probe<return_slot_capacity;probe++,i=(i+1)%return_slot_capacity){
  if(!return_slots[i].node)return 0;
  if(return_slots[i].node==node && return_slots[i].offset==offset)return 1;
 }
 return 0;
}

static void return_slot_note(unsigned char *frame,uintptr_t result){
 if(!frame)return;
 uintptr_t node=*(uintptr_t*)(frame+frame_node),locals=*(uintptr_t*)(frame+frame_locals);
 if(!node || !locals || result<locals || !readable(node,struct_script))return;
 int size=*(int*)(node+struct_properties_size);
 if(size<=0 || result-locals>=(uintptr_t)size || (result-locals)%sizeof(uintptr_t))return;
 int offset=(int)(result-locals);
 if(return_slot_known(node,offset) || return_slot_count>=return_slot_capacity*3/4)return;
 size_t i=return_slot_hash(node,offset);
 while(return_slots[i].node)i=(i+1)%return_slot_capacity;
 return_slots[i].node=node;return_slots[i].offset=offset;
 return_slot_count++;
}

static int subject_scan(uintptr_t node,uintptr_t locals,int size,uintptr_t second,uintptr_t first,uintptr_t exclude,int offsets[2]){
 if(size<=0 || !locals)return 0;
 if(size>subject_scan_bytes)size=subject_scan_bytes;
 if(!readable(locals,(size_t)size))return 0;
 const uintptr_t *slots=(const uintptr_t*)locals;
 size_t n=(size_t)size/sizeof(uintptr_t);
 int found=0;
 for(size_t i=0;i<n && found!=3;i++){
  /* The lookup's own return slot holds the answer, not a subject. */
  if((uintptr_t)&slots[i]==exclude)continue;
  if((slots[i]==second || slots[i]==first) && return_slot_known(node,(int)(i*sizeof(uintptr_t))))continue;
  if(slots[i]==second && !(found&2)){found|=2;offsets[1]=(int)(i*sizeof(uintptr_t));}
  else if(slots[i]==first && !(found&1)){found|=1;offsets[0]=(int)(i*sizeof(uintptr_t));}
 }
 return found;
}

/* The nearest frame that names a player decides. A frame naming both players
 * is ambiguous and must never redirect a lookup. */
/* Script functions keep their locals on the game thread's stack and clear
 * them on entry. Ubergraph locals live on the object and keep old values. */
static int stack_local(uintptr_t p){
 uintptr_t low=0,high=0;
 thread_stack_bounds(&low,&high);
 return low && p>=low && p<high;
}

static int subject_verdict_from(unsigned char *frame,uintptr_t second,uintptr_t first,uintptr_t exclude,int fresh,int *depth,int offsets[2]){
 *depth=-1;offsets[0]=offsets[1]=-1;
 if(!frame || !second || !first)return verdict_none;
 uintptr_t actor=*(uintptr_t*)(frame+frame_object);
 if(actor==second)return verdict_self2;
 if(actor==first)return verdict_self1;
 for(int d=0;d<subject_depth && frame;d++){
  uintptr_t node=*(uintptr_t*)(frame+frame_node);
  uintptr_t locals=*(uintptr_t*)(frame+frame_locals);
  if(node && readable(node,struct_script) && (!fresh || stack_local(locals))){
   int found=subject_scan(node,*(uintptr_t*)(frame+frame_locals),*(int*)(node+struct_properties_size),second,first,exclude,offsets);
   if(found){*depth=d;return found==3?verdict_both:found==2?verdict_p2:verdict_p1;}
  }
  uintptr_t previous=*(uintptr_t*)(frame+frame_previous);
  frame=previous && readable(previous,frame_previous+sizeof(uintptr_t))?(unsigned char*)previous:NULL;
 }
 return verdict_none;
}

static int subject_verdict(unsigned char *frame,uintptr_t second,uintptr_t first,uintptr_t exclude,int *depth,int offsets[2]){
 return subject_verdict_from(frame,second,first,exclude,0,depth,offsets);
}

/* Phase 1, rule 1: a script that is handling P2 (an overlap, a hit, a step)
 * and names no P1 is asking about P2. Only fresh frames decide: the function
 * itself, or the event stub that started the Ubergraph, whose parameters
 * belong to this event. Persistent Ubergraph locals may hold any earlier
 * player and are skipped. Ambiguous frames and the pawns' own Blueprints keep P1. */
enum { frame_rule_depth=2 };
static int frame_names_second(unsigned char *frame,uintptr_t second,uintptr_t first,uintptr_t exclude){
 int depth,offsets[2];
 return subject_verdict_from(frame,second,first,exclude,1,&depth,offsets)==verdict_p2 && depth<=frame_rule_depth;
}

static SubjectEntry *subject_slot(uintptr_t graph,uintptr_t actor){
 size_t i=(size_t)(((graph>>4)*0x9e3779b97f4a7c15ULL)^((actor>>4)*0xc2b2ae3d27d4eb4fULL))%subject_slots;
 for(size_t probe=0;probe<subject_slots;probe++,i=(i+1)%subject_slots){
  SubjectEntry *e=&subject_entries[i];
  if(e->graph==graph && e->actor==actor)return e;
  if(!e->graph){
   if(subject_count>=subject_limit){subject_dropped++;return NULL;}
   memset(e,0,sizeof(*e));
   e->graph=graph;e->actor=actor;
   subject_count++;
   return e;
  }
 }
 subject_dropped++;
 return NULL;
}

static void subject_record(unsigned char *frame,unsigned char *code,int routed,uintptr_t second,uintptr_t first,uintptr_t exclude){
 uintptr_t graph=*(uintptr_t*)(frame+frame_node),actor=*(uintptr_t*)(frame+frame_object);
 if(!graph)return;
 int depth,offsets[2];
 int verdict=subject_verdict(frame,second,first,exclude,&depth,offsets);
 SubjectEntry *e=subject_slot(graph,actor);
 if(!e)return;
 e->counts[verdict]++;
 if(routed)e->routed++;
 /* The object a player holds right now, as reported by Lua each tick. */
 for(int i=0;i<2;i++)if(actor && actor==subject_grab[i])e->grabs[i]++;
 e->depth=depth;
 e->offsets[0]=offsets[0];e->offsets[1]=offsets[1];
 uintptr_t script=readable(graph,struct_script+sizeof(uintptr_t))?*(uintptr_t*)(graph+struct_script):0;
 e->code=script && (uintptr_t)code>=script?(long)((uintptr_t)code-script):-1;
 e->dirty=1;
}

static void subject_reset(void){
 memset(subject_entries,0,sizeof(subject_entries));
 subject_count=subject_cursor=0;
 subject_dropped=0;
 subject_grab[0]=subject_grab[1]=0;
}

static void route_player(unsigned char *frame,unsigned char *code,void *result){
 uintptr_t graph=*(uintptr_t*)(frame+0x10);
 uintptr_t actor=*(uintptr_t*)(frame+0x18);
 if(vent_actor && graph==vent_graph && actor==vent_actor && owns_second()){
  *(uintptr_t*)result=pawn;
  vent_reads++;
  return;
 }
 if(cage_graph && graph==cage_graph && code==cage_code &&
    owns_second() && second_crossed_tripwire(actor)){
  *(uintptr_t*)result=pawn;
  cage_reads++;
  return;
 }
 if(!route_enabled || !owns_second())return;
 if(weapon_hit){
  if(weapon_hit->instigator!=pawn)return;
  if(hit_recipient(weapon_hit,actor)){
   *(uintptr_t*)result=pawn;
   weapon_hit_reads++;
   return;
  }
 }else{
  for(size_t i=0;i<route_count;i++)
   if(route_entries[i].actor==actor && route_entries[i].target==1){
    *(uintptr_t*)result=pawn;
    return;
   }
 }
 /* Lua renews this only during P2's final music box interaction. */
 if(box_pawn==pawn && box_primary==primary_pawn && GetTickCount()-box_route_tick<250 &&
    *(uintptr_t*)result==primary_pawn){
  *(uintptr_t*)result=pawn;
  box_route_reads++;
 }
}

static void interaction_player(void *context,void *stack,void *result){
 unsigned char *frame=stack;
 unsigned char *code=*(unsigned char**)(frame+0x20);
 ((BlueprintNative)(game+0xbe9e00))(context,stack,result);
 if(GetCurrentThreadId()!=game_thread)return;
 uintptr_t original=*(uintptr_t*)result;
 if(route_enabled || subject_enabled)return_slot_note(frame,(uintptr_t)result);
 route_player(frame,code,result);
 if(frame_rule_enabled && route_enabled && !weapon_hit && owns_second() &&
    *(uintptr_t*)result==primary_pawn && primary_pawn &&
    frame_names_second(frame,pawn,primary_pawn,(uintptr_t)result)){
  *(uintptr_t*)result=pawn;
  frame_rule_reads++;
 }
 if(subject_enabled && owns_second())
  subject_record(frame,code,original!=*(uintptr_t*)result,pawn,primary_pawn,(uintptr_t)result);
}

static void release_player_lookup(void){
 if(!player_lookup || vent_actor || cage_graph || route_enabled || subject_enabled)return;
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

static int route_hit_reads(lua_State *L){
 pushint(L,weapon_hit_reads);
 return 1;
}

static int route_music_box(lua_State *L){
 int valid=0;long long on=toint(L,1,&valid);
 if(!valid || (on!=0 && on!=1) || GetCurrentThreadId()!=game_thread)
  return luaerr(L,"Expected box route state on the bound game thread");
 box_pawn=on && route_enabled && owns_second()?pawn:0;
 box_primary=primary_pawn;
 box_route_tick=GetTickCount();
 pushint(L,box_route_reads);
 return 1;
}

static int route_frames(lua_State *L){
 int valid=0;long long on=toint(L,1,&valid);
 if(!valid || (on!=0 && on!=1))return luaerr(L,"Expected frame rule state zero or one");
 if(game_thread && GetCurrentThreadId()!=game_thread)
  return luaerr(L,"The frame rule must change on the bound game thread");
 frame_rule_enabled=(int)on;
 pushint(L,frame_rule_reads);
 return 1;
}

static int route_active(lua_State *L){
 int valid=0;long long on=toint(L,1,&valid);
 if(!valid || (on!=0 && on!=1))return luaerr(L,"Expected route active zero or one");
 if(on){
  if(game_thread && GetCurrentThreadId()!=game_thread)
   return luaerr(L,"The route must be installed on the bound game thread");
  uintptr_t lookup=(uintptr_t)toint(L,2,&valid);
  if(!valid)return luaerr(L,"Expected player lookup address");
  if(!install_weapon_dispatch())return luaerr(L,"The weapon hit dispatcher does not match the supported build");
  install_player_lookup(L,lookup);
  route_enabled=1;
 }else{
  route_enabled=0;
  frame_rule_enabled=0;
  box_pawn=0;
  free(route_entries);route_entries=NULL;route_count=route_capacity=0;
  release_player_lookup();
 }
 return 0;
}


static void push_names(lua_State *L,const char *prefix,uintptr_t object,int levels){
 char key[4];
 for(int i=1;i<=levels && object && readable(object,0x28);i++){
  key[0]=prefix[0];key[1]=(char)('0'+i);key[2]=0;key[3]=0;
  pushint(L,*(unsigned int*)(object+0x18));setfield(L,-2,key);
  key[2]='n';
  pushint(L,*(unsigned int*)(object+0x1c));setfield(L,-2,key);
  object=*(uintptr_t*)(object+0x20);
 }
}

static int subject_observe(lua_State *L){
 int valid=0;long long on=toint(L,1,&valid);
 if(!valid || (on!=0 && on!=1))return luaerr(L,"Expected subject observation zero or one");
 if(game_thread && GetCurrentThreadId()!=game_thread)
  return luaerr(L,"Subject observation must run on the bound game thread");
 if(on){
  uintptr_t lookup=(uintptr_t)toint(L,2,&valid);
  if(!valid)return luaerr(L,"Expected player lookup address");
  install_player_lookup(L,lookup);
  if(!subject_enabled)subject_reset();
  subject_enabled=1;
 }else{
  subject_enabled=0;
  subject_reset();
  release_player_lookup();
 }
 return 0;
}

static int subject_next(lua_State *L){
 if(GetCurrentThreadId()!=game_thread)return 0;
 for(size_t n=0;n<subject_slots;n++){
  SubjectEntry *e=&subject_entries[subject_cursor];
  subject_cursor=(subject_cursor+1)%subject_slots;
  if(!e->graph || !e->dirty)continue;
  e->dirty=0;
  newtable(L,0,26);
  static const char *names[verdict_count]={"none","p1","p2","both","self1","self2"};
  for(int v=0;v<verdict_count;v++){pushint(L,e->counts[v]);setfield(L,-2,names[v]);}
  pushint(L,e->routed);setfield(L,-2,"routed");
  pushint(L,e->depth);setfield(L,-2,"depth");
  pushint(L,e->grabs[0]);setfield(L,-2,"grab1");
  pushint(L,e->grabs[1]);setfield(L,-2,"grab2");
  pushint(L,e->offsets[0]);setfield(L,-2,"slot1");
  pushint(L,e->offsets[1]);setfield(L,-2,"slot2");
  pushint(L,e->code);setfield(L,-2,"code");
  pushint(L,(long long)e->graph);setfield(L,-2,"graph");
  pushint(L,(long long)e->actor);setfield(L,-2,"actor");
  push_names(L,"g",e->graph,4);
  push_names(L,"a",e->actor,5);
  if(e->actor && readable(e->actor,0x28))push_names(L,"c",*(uintptr_t*)(e->actor+0x10),1);
  return 1;
 }
 return 0;
}

static int subject_grabs(lua_State *L){
 int valid=0;
 for(int i=0;i<2;i++){
  long long value=toint(L,i+1,&valid);
  if(!valid)return luaerr(L,"Expected two grabbed actor addresses");
  subject_grab[i]=(uintptr_t)value;
 }
 return 0;
}

static int subject_stats(lua_State *L){
 pushint(L,(long long)subject_count);
 pushint(L,subject_dropped);
 return 2;
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
 API(lua_gettop,gettop);
 API(lua_tointegerx,toint);API(lua_tonumberx,tonum);API(lua_pushboolean,pushbool);
 API(lua_pushinteger,pushint);API(lua_pushstring,pushstr);API(lua_pushcclosure,pushfn);
 API(lua_createtable,newtable);API(lua_setfield,setfield);API(luaL_error,luaerr);
 if(!identity(game,GAME_TIMESTAMP,GAME_IMAGE_SIZE))return luaerr(L,"Unsupported Little Nightmares II build");
 const unsigned char signature[]={0x40,0x53,0x48,0x83,0xec,0x40,0x0f,0x29,0x74,0x24,0x30};
 if(memcmp(game+0xae0510,signature,sizeof(signature))!=0)return luaerr(L,"Native crouch signature does not match");
 newtable(L,0,27);
 field(L,"bind",bind_owner);field(L,"crouch",crouch);field(L,"use_item",use_item);
 field(L,"six_crouch",six_crouch);
 field(L,"jump",jump);
 field(L,"vent",route_vent);
 field(L,"cage",route_cage);
 field(L,"route_actor",route_actor);
 field(L,"route_frames",route_frames);
 field(L,"route_clear",route_clear);
 field(L,"route_active",route_active);
 field(L,"route_hit_reads",route_hit_reads);
 field(L,"route_music_box",route_music_box);
 field(L,"subject_observe",subject_observe);
 field(L,"subject_next",subject_next);
 field(L,"subject_stats",subject_stats);
 field(L,"subject_grabs",subject_grabs);
 field(L,"school_escort",school_escort);
 field(L,"school_escort_reads",school_escort_reads);
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
 pushstr(L,"Helios original / guarded P2 adapter with event instigators, school escort and subject observation");setfield(L,-2,"version");
 return 1;
}
