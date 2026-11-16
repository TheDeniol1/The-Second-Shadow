// Compile the actual aspect override helpers against an isolated camera buffer.
const fs=require('fs'),path=require('path'),os=require('os'),cp=require('child_process');
const root=path.resolve(__dirname,'..');
const source=fs.readFileSync(path.join(root,'tools/native-build/ln2_native.c'),'utf8');
const start=source.indexOf('typedef struct { uintptr_t view,controller;');
const end=source.indexOf('static int camera_fill(',start);
if(start<0||end<0)throw Error('Native aspect helpers not found');
const harness=`
#include <stdint.h>
#include <string.h>
#include <assert.h>
static int fill_split_view=1,camera_mode=2,owned=1;
static int readable(uintptr_t p,unsigned long n){return p!=0;}
static int owns_second(void){return owned;}
${source.slice(start,end)}
int main(void){
 unsigned char view[0x1b00]={0},second[0x1b00]={0},controller[0x300]={0},other[0x300]={0};
 *(uintptr_t*)(controller+0x2b0)=(uintptr_t)view;
 *(uintptr_t*)(view+0x218)=(uintptr_t)controller;
 *(uintptr_t*)(other+0x2b0)=(uintptr_t)second;
 *(uintptr_t*)(second+0x218)=(uintptr_t)other;
 view[0x1a50]=0xad;second[0x1a50]=0x7b;
 apply_aspect(view,0);apply_aspect(second,1);
 assert(view[0x1a50]==0xac && second[0x1a50]==0x7a);
 restore_aspect(&aspect_overrides[0]);restore_aspect(&aspect_overrides[1]);
 assert(view[0x1a50]==0xad && second[0x1a50]==0x7b);
 view[0x1a50]=0xac;apply_aspect(view,0);restore_aspect(&aspect_overrides[0]);
 assert(view[0x1a50]==0xac);
 view[0x1a50]=1;apply_aspect(view,0);
 *(float*)(view+0x1a10)=2;view[0x1a50]=0x44;
 restore_aspect(&aspect_overrides[0]);assert(view[0x1a50]==0x44);
 view[0x1a50]=1;apply_aspect(view,0);*(uintptr_t*)(controller+0x2b0)=0;
 restore_aspect(&aspect_overrides[0]);assert(view[0x1a50]==0);
 view[0x1a50]=1;camera_mode=1;apply_aspect(view,0);assert(view[0x1a50]==1);
 camera_mode=2;fill_split_view=0;apply_aspect(view,0);assert(view[0x1a50]==1);
 fill_split_view=1;owned=0;apply_aspect(view,0);assert(view[0x1a50]==1);
 return 0;
}`;
const base=path.join(os.tmpdir(),'ln2-aspect-'+process.pid);
try{
 fs.writeFileSync(base+'.c',harness);
 cp.execFileSync((process.env.TCC || 'tcc'),['-o',base+'.exe',base+'.c'],{stdio:'inherit'});
 cp.execFileSync(base+'.exe',[],{stdio:'inherit'});
 console.log('PASS: native aspect flags, both views, restoration, fresh frames and ownership gates.');
}finally{
 for(const ext of ['.c','.exe'])if(fs.existsSync(base+ext))fs.unlinkSync(base+ext);
}
