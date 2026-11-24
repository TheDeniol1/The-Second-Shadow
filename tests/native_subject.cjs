// Compile the actual event subject helpers against fake Blueprint frames.
const fs=require('fs'),path=require('path'),os=require('os'),cp=require('child_process');
const root=path.resolve(__dirname,'..');
const source=fs.readFileSync(path.join(root,'tools/native-build/ln2_native.c'),'utf8');
const start=source.indexOf('/* Event subject observation');
const end=source.indexOf('static void subject_reset(void){',start);
if(start<0||end<0)throw Error('Native subject helpers not found');
const harness=`
#include <stdint.h>
#include <string.h>
#include <assert.h>
static int readable(uintptr_t p,unsigned long n){return p!=0;}
/* The test thread's stack: from 8 MB below main's frame to just above it. */
static uintptr_t test_stack_top;
static void thread_stack_bounds(uintptr_t *low,uintptr_t *high){
 uintptr_t span=(uintptr_t)1<<20; /* main's arrays sit well within 1 MB */
 *high=test_stack_top;*low=test_stack_top>span?test_stack_top-span:1;
}
${source.slice(start,end)}
typedef struct { unsigned char bytes[0x100]; } Frame;
static void frame(Frame *f,void *node,void *object,void *locals,void *previous){
 memset(f,0,sizeof(*f));
 *(void**)(f->bytes+frame_node)=node;
 *(void**)(f->bytes+frame_object)=object;
 *(void**)(f->bytes+frame_locals)=locals;
 *(void**)(f->bytes+frame_previous)=previous;
}
int main(void){
 volatile char top;test_stack_top=(uintptr_t)&top+0x10000;
 unsigned char graph[0x80]={0},stub[0x80]={0},script[0x600]={0};
 uintptr_t first=0x1111000,second=0x2222000,level=0x3333000,actor=0x4444000;
 uintptr_t locals[64]={0},event[8]={0};
 *(int*)(graph+struct_properties_size)=sizeof(locals);
 *(int*)(stub+struct_properties_size)=sizeof(event);
 *(uintptr_t*)(graph+struct_script)=(uintptr_t)script;
 Frame f,caller;int depth,slots[2];
 frame(&f,graph,(void*)actor,locals,NULL);
 assert(subject_verdict(f.bytes,second,first,0,&depth,slots)==verdict_none && depth==-1 && slots[0]==-1 && slots[1]==-1);
 locals[9]=second;
 assert(subject_verdict(f.bytes,second,first,0,&depth,slots)==verdict_p2 && depth==0);
 locals[20]=first;
 assert(subject_verdict(f.bytes,second,first,0,&depth,slots)==verdict_both && slots[0]==160 && slots[1]==72);
 locals[9]=0;
 assert(subject_verdict(f.bytes,second,first,0,&depth,slots)==verdict_p1);
 locals[20]=0;
 /* A fresh event stub one frame up names P2; the persistent frame names nobody. */
 event[1]=second;
 frame(&caller,stub,(void*)actor,event,NULL);
 frame(&f,graph,(void*)actor,locals,caller.bytes);
 assert(subject_verdict(f.bytes,second,first,0,&depth,slots)==verdict_p2 && depth==1);
 /* The nearest frame decides: a persistent P1 wins over an older P2 caller. */
 locals[3]=first;
 assert(subject_verdict(f.bytes,second,first,0,&depth,slots)==verdict_p1 && depth==0);
 locals[3]=0;
 /* The player's own Blueprint is its own subject. */
 frame(&f,graph,(void*)second,locals,NULL);
 assert(subject_verdict(f.bytes,second,first,0,&depth,slots)==verdict_self2);
 frame(&f,graph,(void*)first,locals,NULL);
 assert(subject_verdict(f.bytes,second,first,0,&depth,slots)==verdict_self1);
 /* The scan is bounded and ignores frames beyond the depth limit. */
 Frame chain[6];
 uintptr_t empty[2]={0},deep[2]={second,0};
 *(int*)(stub+struct_properties_size)=sizeof(empty);
 frame(&chain[5],stub,(void*)level,deep,NULL);
 for(int i=4;i>=0;i--)frame(&chain[i],stub,(void*)level,empty,chain[i+1].bytes);
 assert(subject_verdict(chain[0].bytes,second,first,0,&depth,slots)==verdict_none);
 frame(&chain[3],stub,(void*)level,deep,NULL);
 assert(subject_verdict(chain[0].bytes,second,first,0,&depth,slots)==verdict_p2 && depth==3);
 /* No P2 bound means no verdict. */
 assert(subject_verdict(chain[0].bytes,0,first,0,&depth,slots)==verdict_none);
 /* An overlap naming P2 whose lookup result (P1) sits in the same frame:
  * the return slot is not a subject, so the frame names only P2. */
 locals[9]=second;locals[10]=first;
 frame(&f,graph,(void*)actor,locals,NULL);
 assert(subject_verdict(f.bytes,second,first,0,&depth,slots)==verdict_both);
 assert(subject_verdict(f.bytes,second,first,(uintptr_t)&locals[10],&depth,slots)==verdict_p2);
 assert(frame_names_second(f.bytes,second,first,(uintptr_t)&locals[10]));
 assert(!frame_names_second(f.bytes,second,first,0)); /* ambiguous keeps P1 */
 assert(!frame_names_second(f.bytes,second,first,(uintptr_t)&locals[9])); /* only P1 left */
 locals[10]=0;
 assert(frame_names_second(f.bytes,second,first,0));
 /* The direct caller may decide, deeper frames may not. */
 locals[9]=0;event[1]=second;
 *(int*)(stub+struct_properties_size)=sizeof(event);
 frame(&caller,stub,(void*)actor,event,NULL);
 frame(&f,graph,(void*)actor,locals,caller.bytes);
 assert(frame_names_second(f.bytes,second,first,0));
 unsigned char small[0x80]={0};
 *(int*)(small+struct_properties_size)=sizeof(empty);
 frame(&chain[3],stub,(void*)level,event,NULL);
 frame(&chain[2],small,(void*)level,empty,chain[3].bytes);
 frame(&chain[1],small,(void*)level,empty,chain[2].bytes);
 assert(frame_names_second(chain[1].bytes,second,first,0)); /* helper, Ubergraph, stub */
 frame(&chain[0],small,(void*)level,empty,chain[1].bytes);
 assert(subject_verdict(chain[0].bytes,second,first,0,&depth,slots)==verdict_p2 && depth==3);
 assert(!frame_names_second(chain[0].bytes,second,first,0));
 /* The pawns' own Blueprints are never redirected by the frame rule. */
 frame(&f,graph,(void*)second,locals,NULL);
 assert(!frame_names_second(f.bytes,second,first,0));
 frame(&f,graph,(void*)first,locals,NULL);
 assert(!frame_names_second(f.bytes,second,first,0));
 event[1]=0;
 /* A persistent Ubergraph keeps an old lookup answer (P1) beside a fresh
  * overlap parameter (P2). Once that slot is known as a return slot, the
  * frame names only P2; the same offset in another graph still counts. */
 locals[5]=first;locals[9]=second;
 frame(&f,graph,(void*)actor,locals,NULL);
 assert(subject_verdict(f.bytes,second,first,0,&depth,slots)==verdict_both);
 return_slot_note(f.bytes,(uintptr_t)&locals[5]);
 return_slot_note(f.bytes,(uintptr_t)&locals[5]);
 assert(return_slot_count==1 && return_slot_known((uintptr_t)graph,40));
 assert(subject_verdict(f.bytes,second,first,0,&depth,slots)==verdict_p2 && slots[1]==72 && slots[0]==-1);
 assert(frame_names_second(f.bytes,second,first,0));
 /* A P2 answer left in that slot after a redirect is not a subject either. */
 locals[9]=0;locals[5]=second;
 assert(subject_verdict(f.bytes,second,first,0,&depth,slots)==verdict_none);
 locals[5]=first;locals[9]=second;
 /* Called from that graph: a helper with no players defers to its caller. */
 uintptr_t none[4]={0};
 unsigned char helper[0x80]={0};
 *(int*)(helper+struct_properties_size)=sizeof(none);
 Frame inner;
 frame(&inner,helper,(void*)actor,none,f.bytes);
 assert(frame_names_second(inner.bytes,second,first,0));
 /* Pointers outside the frame or misaligned are ignored. */
 return_slot_note(f.bytes,(uintptr_t)&locals[64]);
 return_slot_note(f.bytes,(uintptr_t)&locals[3]+4);
 assert(return_slot_count==1);
 /* Another graph with P1 at the same offset still names P1. */
 unsigned char other[0x80]={0};
 *(int*)(other+struct_properties_size)=sizeof(locals);
 frame(&f,other,(void*)actor,locals,NULL);
 assert(subject_verdict(f.bytes,second,first,0,&depth,slots)==verdict_both);
 locals[5]=0;locals[9]=0;
 /* Ubergraph locals live off the stack and keep old players: they never
  * decide the frame rule, while the fresh event stub that called them does. */
 static uintptr_t persistent[16];
 persistent[2]=second;
 Frame uber,starter;
 unsigned char uber_node[0x80]={0};
 *(int*)(uber_node+struct_properties_size)=sizeof(persistent);
 frame(&uber,uber_node,(void*)actor,persistent,NULL);
 assert(subject_verdict(uber.bytes,second,first,0,&depth,slots)==verdict_p2);
 assert(!frame_names_second(uber.bytes,second,first,0));
 uintptr_t params[4]={0,second,0,0};
 unsigned char starter_node[0x80]={0};
 *(int*)(starter_node+struct_properties_size)=sizeof(params);
 frame(&starter,starter_node,(void*)actor,params,NULL);
 persistent[2]=first; /* the Ubergraph still remembers P1 */
 frame(&uber,uber_node,(void*)actor,persistent,starter.bytes);
 assert(subject_verdict(uber.bytes,second,first,0,&depth,slots)==verdict_p1);
 assert(frame_names_second(uber.bytes,second,first,0));
 params[3]=first; /* an event naming both stays with P1 */
 assert(!frame_names_second(uber.bytes,second,first,0));
 persistent[2]=0;
 /* Records aggregate by graph and actor and keep the script offset. */
 locals[9]=second;
 frame(&f,graph,(void*)actor,locals,NULL);
 subject_record(f.bytes,script+0x49f,1,second,first,0);
 subject_grab[1]=actor;
 subject_record(f.bytes,script+0x4a7,0,second,first,0);
 subject_grab[1]=0;subject_grab[0]=actor;
 SubjectEntry *e=subject_slot((uintptr_t)graph,actor);
 assert(subject_count==1 && e->counts[verdict_p2]==2 && e->routed==1 && e->code==0x4a7 && e->dirty);
 assert(e->grabs[1]==1 && e->grabs[0]==0 && e->offsets[1]==72 && e->offsets[0]==-1);
 subject_record(f.bytes,script,0,second,first,0);
 assert(e->grabs[0]==1); /* a P1 grab is counted separately */
 for(uintptr_t i=1;i<=subject_limit+5;i++){frame(&f,graph,(void*)(actor+i*16),locals,NULL);subject_record(f.bytes,script,0,second,first,0);}
 subject_grab[0]=0;
 assert(subject_count==subject_limit && subject_dropped==6);
 return 0;
}`;
const base=path.join(os.tmpdir(),'ln2-subject-'+process.pid);
const exe=base+(process.platform==='win32'?'.exe':'');
const compiler=process.platform==='win32'?path.join(root,'tools/native-build/tcc/tcc.exe'):(process.env.CC||'cc');
try{
 fs.writeFileSync(base+'.c',harness);
 cp.execFileSync(compiler,['-o',exe,base+'.c'],{stdio:'inherit'});
 cp.execFileSync(exe,[],{stdio:'inherit'});
 console.log('PASS: native subject verdicts, nearest frame, ambiguity slots, return slot, stored answers, fresh frames only, frame rule depth, held objects, own pawn, depth bound and bounded records.');
}finally{
 for(const file of [base+'.c',exe])if(fs.existsSync(file))fs.unlinkSync(file);
}
