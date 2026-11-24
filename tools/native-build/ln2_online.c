/* The Second Shadow · modo online, fase 0 (prueba de concepto).
 * Comprueba, sin enganchar nada del juego, las piezas que necesita el modo
 * online: captura de pantalla con la duplicacion de escritorio de DXGI,
 * codificador y decodificador H.264 de Media Foundation, Winsock y la red de
 * Steam que el juego ya carga. Todo se ejecuta en un hilo propio y el informe
 * se recoge desde Lua con probe_poll().
 * TinyCC no trae cabeceras de D3D11, DXGI ni Media Foundation: los interfaces
 * COM se llaman por su indice de vtable y las DLL del sistema se cargan con
 * LoadLibrary, asi no hacen falta bibliotecas de importacion. */
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include "lua-rvas.h"
#include "runtime-identity.h"
/* Las cabeceras de TinyCC no traen winnls.h: declaracion minima. */
#ifndef CP_UTF8
#define CP_UTF8 65001
WINBASEAPI int WINAPI WideCharToMultiByte(UINT,DWORD,LPCWSTR,int,LPSTR,int,LPCSTR,LPBOOL);
#endif

#define ONLINE_VERSION "ln2_online 02 / fase 1: diagnostico y sesion por la red de Steam"

typedef struct lua_State lua_State;
typedef int (*LuaFn)(lua_State*);
static void (*pushstr)(lua_State*,const char*);
static void (*pushbool)(lua_State*,int);
static void (*pushint)(lua_State*,long long);
static long long (*toint)(lua_State*,int,int*);
static void (*pushfn)(lua_State*,LuaFn,int);
static void (*newtable)(lua_State*,int,int);
static void (*setfield)(lua_State*,int,const char*);
static int (*luaerr)(lua_State*,const char*,...);

/* ---------- informe ---------- */
#define REPORT_SIZE 16384
static char report[REPORT_SIZE];
static size_t report_len;
static volatile LONG probe_state; /* 0 libre, 1 en curso, 2 terminado */
static HANDLE probe_thread;

static void say(const char *fmt,...){
 va_list args;va_start(args,fmt);
 if(report_len<REPORT_SIZE-2){
  int n=vsnprintf(report+report_len,REPORT_SIZE-2-report_len,fmt,args);
  if(n>0)report_len+=(size_t)n<REPORT_SIZE-2-report_len?(size_t)n:REPORT_SIZE-2-report_len;
  report[report_len++]='\n';report[report_len]=0;
 }
 va_end(args);
}
static void wide(char *out,size_t size,const WCHAR *in){
 if(!WideCharToMultiByte(CP_UTF8,0,in,-1,out,(int)size,NULL,NULL))out[0]=0;
 out[size-1]=0;
}
static double now_ms(void){
 static LARGE_INTEGER freq;LARGE_INTEGER t;
 if(!freq.QuadPart)QueryPerformanceFrequency(&freq);
 QueryPerformanceCounter(&t);
 return (double)t.QuadPart*1000.0/(double)freq.QuadPart;
}

/* ---------- COM por vtable ---------- */
#define VT(obj,i) ((*(void***)(obj))[i])
typedef HRESULT (WINAPI *QueryFn)(void*,const GUID*,void**);
typedef ULONG (WINAPI *ReleaseFn)(void*);
static void release(void *obj){ if(obj)((ReleaseFn)VT(obj,2))(obj); }
static HRESULT query(void *obj,const GUID *iid,void **out){ return ((QueryFn)VT(obj,0))(obj,iid,out); }
#define G(name,a,b,c,d0,d1,d2,d3,d4,d5,d6,d7) static const GUID name={a,b,c,{d0,d1,d2,d3,d4,d5,d6,d7}}
G(IID_IDXGIFactory1,0x770aae78,0xf26f,0x4dba,0xa8,0x29,0x25,0x3c,0x83,0xd1,0xb3,0x87);
G(IID_IDXGIOutput1,0x00cddea8,0x939b,0x4b83,0xa3,0x40,0xa6,0x85,0x22,0x66,0x66,0xcc);
G(IID_ID3D11Texture2D,0x6f15aaf2,0xd208,0x4e89,0x9a,0xb4,0x48,0x95,0x35,0xd3,0x4f,0x9c);
G(IID_IMFTransform,0xbf94c121,0x5b05,0x4e6f,0x80,0x00,0xba,0x59,0x89,0x61,0x41,0x4d);
G(MFT_CATEGORY_VIDEO_ENCODER,0xf79eac7d,0xe545,0x4387,0xbd,0xee,0xd6,0x47,0xd7,0xbd,0xe4,0x2a);
G(MFT_CATEGORY_VIDEO_DECODER,0xd6c02d4b,0x6833,0x45b4,0x97,0x1a,0x05,0xa4,0xb0,0x4b,0xab,0x91);
G(MFMediaType_Video,0x73646976,0x0000,0x0010,0x80,0x00,0x00,0xaa,0x00,0x38,0x9b,0x71);
G(MFVideoFormat_H264,0x34363248,0x0000,0x0010,0x80,0x00,0x00,0xaa,0x00,0x38,0x9b,0x71);
G(MFVideoFormat_NV12,0x3231564e,0x0000,0x0010,0x80,0x00,0x00,0xaa,0x00,0x38,0x9b,0x71);
G(MFT_FRIENDLY_NAME_Attribute,0x314ffbae,0x5b41,0x4c95,0x9c,0x19,0x4e,0x7d,0x58,0x6f,0xac,0xe3);
G(MF_MT_MAJOR_TYPE,0x48eba18e,0xf8c9,0x4687,0xbf,0x11,0x0a,0x74,0xc9,0xf9,0x6a,0x8f);
G(MF_MT_SUBTYPE,0xf7e34c9a,0x42e8,0x4714,0xb7,0x4b,0xcb,0x29,0xd7,0x2c,0x35,0xe5);
G(MF_MT_FRAME_SIZE,0x1652c33d,0xd6b2,0x4012,0xb8,0x34,0x72,0x03,0x08,0x49,0xa3,0x7d);
G(MF_MT_FRAME_RATE,0xc459a2e8,0x3d2c,0x4e44,0xb1,0x32,0xfe,0xe5,0x15,0x6c,0x7b,0xb0);
G(MF_MT_AVG_BITRATE,0x20332624,0xfb0d,0x4d9e,0xbd,0x0d,0xcb,0xf6,0x78,0x6c,0x10,0x2e);
G(MF_MT_INTERLACE_MODE,0xe2724bb8,0xe676,0x4806,0xb4,0xb2,0xa8,0xd6,0xef,0xb4,0x4c,0xcd);
G(MF_MT_PIXEL_ASPECT_RATIO,0xc6376a1e,0x8d0a,0x4027,0xbe,0x45,0x6d,0x9a,0x0a,0xd3,0x9b,0xb6);

/* ---------- sistema ---------- */
static void probe_system(void){
 typedef LONG (WINAPI *RtlVersion)(OSVERSIONINFOW*);
 OSVERSIONINFOW v;memset(&v,0,sizeof(v));v.dwOSVersionInfoSize=sizeof(v);
 RtlVersion get=(RtlVersion)GetProcAddress(GetModuleHandleW(L"ntdll.dll"),"RtlGetVersion");
 if(get && get(&v)==0){
  say("Sistema: Windows %lu.%lu compilacion %lu",v.dwMajorVersion,v.dwMinorVersion,v.dwBuildNumber);
  say("Audio por proceso (WASAPI): %s",v.dwBuildNumber>=19041?"disponible":"NO disponible, requiere Windows 10 2004 o posterior");
 }else say("Sistema: version desconocida");
}

/* ---------- captura con duplicacion de escritorio ---------- */
static BOOL CALLBACK find_window(HWND w,LPARAM out){
 DWORD pid=0;GetWindowThreadProcessId(w,&pid);
 if(pid==GetCurrentProcessId() && IsWindowVisible(w) && !GetWindow(w,GW_OWNER)){
  RECT r;GetWindowRect(w,&r);
  if(r.right-r.left>320 && r.bottom-r.top>200){*(HWND*)out=w;return FALSE;}
 }
 return TRUE;
}
typedef struct { UINT width,height,num,den,format,scanline,scaling; UINT rotation; BOOL in_memory; } DuplDesc;
typedef struct { WCHAR name[32]; RECT coords; BOOL attached; UINT rotation; HMONITOR monitor; } OutputDesc;
typedef struct { WCHAR description[128]; UINT vendor,device,subsys,revision; SIZE_T vram,sysmem,shared; LUID luid; UINT flags; } AdapterDesc1;
static void probe_capture(void){
 HWND window=NULL;EnumWindows(find_window,(LPARAM)&window);
 HMONITOR monitor=window?MonitorFromWindow(window,MONITOR_DEFAULTTOPRIMARY):MonitorFromPoint((POINT){0,0},MONITOR_DEFAULTTOPRIMARY);
 if(window){
  RECT r;GetClientRect(window,&r);
  say("Ventana del juego: %ldx%ld",r.right-r.left,r.bottom-r.top);
 }else say("Ventana del juego: no encontrada, se usa el monitor principal");
 HMODULE dxgi=LoadLibraryW(L"dxgi.dll"),d3d=LoadLibraryW(L"d3d11.dll");
 typedef HRESULT (WINAPI *CreateFactory)(const GUID*,void**);
 typedef HRESULT (WINAPI *CreateDevice)(void*,int,HMODULE,UINT,const int*,UINT,UINT,void**,int*,void**);
 CreateFactory create_factory=dxgi?(CreateFactory)GetProcAddress(dxgi,"CreateDXGIFactory1"):NULL;
 CreateDevice create_device=d3d?(CreateDevice)GetProcAddress(d3d,"D3D11CreateDevice"):NULL;
 if(!create_factory||!create_device){say("Captura: DXGI o D3D11 no disponibles");return;}
 void *factory=NULL,*adapter=NULL,*output=NULL,*output1=NULL,*device=NULL,*context=NULL,*dupl=NULL;
 HRESULT hr=create_factory(&IID_IDXGIFactory1,&factory);
 if(FAILED(hr)){say("Captura: CreateDXGIFactory1 fallo 0x%08lx",(unsigned long)hr);return;}
 typedef HRESULT (WINAPI *EnumFn)(void*,UINT,void**);
 for(UINT a=0;!output && ((EnumFn)VT(factory,12))(factory,a,&adapter)==S_OK;a++){
  for(UINT o=0;((EnumFn)VT(adapter,7))(adapter,o,&output)==S_OK;o++){
   OutputDesc od;
   if(((HRESULT(WINAPI*)(void*,OutputDesc*))VT(output,7))(output,&od)==S_OK && od.monitor==monitor)break;
   release(output);output=NULL;
  }
  if(!output){release(adapter);adapter=NULL;}
 }
 if(!output){say("Captura: no se encontro la salida DXGI del monitor del juego");release(factory);return;}
 AdapterDesc1 ad;char name[256];
 if(((HRESULT(WINAPI*)(void*,AdapterDesc1*))VT(adapter,10))(adapter,&ad)==S_OK){
  wide(name,sizeof(name),ad.description);
  say("GPU: %s (%llu MB)",name,(unsigned long long)(ad.vram>>20));
 }
 int level=0;
 hr=create_device(adapter,0/*UNKNOWN*/,NULL,0x20/*BGRA*/,NULL,0,7,&device,&level,&context);
 if(FAILED(hr)){say("Captura: D3D11CreateDevice fallo 0x%08lx",(unsigned long)hr);goto done;}
 say("D3D11: nivel 0x%x",level);
 hr=query(output,&IID_IDXGIOutput1,&output1);
 if(FAILED(hr)){say("Captura: IDXGIOutput1 no disponible 0x%08lx",(unsigned long)hr);goto done;}
 hr=((HRESULT(WINAPI*)(void*,void*,void**))VT(output1,22))(output1,device,&dupl);
 if(FAILED(hr)){
  say("Captura: DuplicateOutput fallo 0x%08lx%s",(unsigned long)hr,
   hr==(HRESULT)0x887A0004?" (no admitido: en portatiles con dos GPU, el juego puede usar otra)":
   hr==(HRESULT)0x80070005?" (acceso denegado: pantalla bloqueada o de seguridad)":
   hr==(HRESULT)0x887A0022?" (demasiadas capturas activas)":"");
  goto done;
 }
 DuplDesc dd;((void(WINAPI*)(void*,DuplDesc*))VT(dupl,7))(dupl,&dd);
 say("Captura: %ux%u a %u/%u Hz, formato %u",dd.width,dd.height,dd.num,dd.den?dd.den:1,dd.format);
 /* Un segundo de captura con copia a una textura propia, como hara el anfitrion. */
 unsigned char info[64];void *resource=NULL,*texture=NULL,*copy=NULL;
 int frames=0,timeouts=0;double copy_ms=0,start=now_ms();
 while(now_ms()-start<1000.0){
  memset(info,0,sizeof(info));
  hr=((HRESULT(WINAPI*)(void*,UINT,void*,void**))VT(dupl,8))(dupl,50,info,&resource);
  if(hr==(HRESULT)0x887A0027){timeouts++;continue;}
  if(FAILED(hr)){say("Captura: AcquireNextFrame fallo 0x%08lx",(unsigned long)hr);break;}
  double t=now_ms();
  if(query(resource,&IID_ID3D11Texture2D,&texture)==S_OK){
   if(!copy){
    UINT desc[11];
    ((void(WINAPI*)(void*,UINT*))VT(texture,10))(texture,desc);
    desc[2]=1;desc[3]=1;desc[7]=0;desc[8]=0;desc[9]=0;desc[10]=0; /* textura propia, uso por defecto */
    if(FAILED(((HRESULT(WINAPI*)(void*,const UINT*,const void*,void**))VT(device,5))(device,desc,NULL,&copy)))copy=NULL;
   }
   /* Copia en la GPU y Flush: el mismo coste que pagara el anfitrion. */
   if(copy)((void(WINAPI*)(void*,void*,void*))VT(context,47))(context,copy,texture);
   ((void(WINAPI*)(void*))VT(context,111))(context);
   release(texture);texture=NULL;
  }
  copy_ms+=now_ms()-t;frames++;
  release(resource);resource=NULL;
  ((HRESULT(WINAPI*)(void*))VT(dupl,14))(dupl);
 }
 release(copy);
 say("Captura: %d imagenes en 1 s (%d esperas), %.2f ms de media por imagen",frames,timeouts,frames?copy_ms/frames:0.0);
 if(frames<20)say("Captura: pocas imagenes; si el juego estaba en pantalla completa exclusiva, prueba en ventana sin bordes");
done:
 release(dupl);release(output1);release(context);release(device);release(output);release(adapter);release(factory);
}

/* ---------- Media Foundation ---------- */
typedef struct { GUID major,sub; } TypeInfo;
typedef HRESULT (WINAPI *EnumMft)(GUID,UINT32,const TypeInfo*,const TypeInfo*,void***,UINT32*);
typedef HRESULT (WINAPI *CreateType)(void**);
typedef HRESULT (WINAPI *CreateSample)(void**);
typedef HRESULT (WINAPI *CreateBuffer)(DWORD,void**);
static EnumMft mft_enum;static CreateType mf_type;static CreateSample mf_sample;static CreateBuffer mf_buffer;
static void (WINAPI *task_free)(void*);
static UINT32 list_mfts(const GUID *category,UINT32 flags,const TypeInfo *in,const TypeInfo *out,const char *label,void **first){
 void **items=NULL;UINT32 count=0;
 HRESULT hr=mft_enum(*category,flags,in,out,&items,&count);
 if(FAILED(hr)){say("%s: MFTEnumEx fallo 0x%08lx",label,(unsigned long)hr);return 0;}
 say("%s: %u",label,count);
 for(UINT32 i=0;i<count;i++){
  WCHAR *text=NULL;UINT32 length=0;char name[200]="(sin nombre)";
  if(((HRESULT(WINAPI*)(void*,const GUID*,WCHAR**,UINT32*))VT(items[i],13))(items[i],&MFT_FRIENDLY_NAME_Attribute,&text,&length)==S_OK){
   wide(name,sizeof(name),text);task_free(text);
  }
  say("  - %s",name);
  if(first && i==0)*first=items[i];else release(items[i]);
 }
 if(items)task_free(items);
 return count;
}
#define SET_GUID(o,k,v) ((HRESULT(WINAPI*)(void*,const GUID*,const GUID*))VT(o,24))(o,&k,&v)
#define SET_U32(o,k,v) ((HRESULT(WINAPI*)(void*,const GUID*,UINT32))VT(o,21))(o,&k,v)
#define SET_U64(o,k,v) ((HRESULT(WINAPI*)(void*,const GUID*,UINT64))VT(o,22))(o,&k,v)
static void *video_type(const GUID *sub,UINT32 w,UINT32 h){
 void *t=NULL;if(FAILED(mf_type(&t)))return NULL;
 SET_GUID(t,MF_MT_MAJOR_TYPE,MFMediaType_Video);
 SET_GUID(t,MF_MT_SUBTYPE,*sub);
 SET_U64(t,MF_MT_FRAME_SIZE,((UINT64)w<<32)|h);
 SET_U64(t,MF_MT_FRAME_RATE,((UINT64)60<<32)|1);
 SET_U64(t,MF_MT_PIXEL_ASPECT_RATIO,((UINT64)1<<32)|1);
 SET_U32(t,MF_MT_INTERLACE_MODE,2);
 return t;
}
typedef struct { DWORD id; void *sample; DWORD status; void *events; } OutputBuffer;
typedef struct { DWORD flags,size,alignment; } StreamInfo;
static size_t drain_output(void *mft,DWORD out_size,int *packets){
 size_t bytes=0;
 for(;;){
  void *sample=NULL,*buffer=NULL;
  if(FAILED(mf_sample(&sample)))break;
  if(FAILED(mf_buffer(out_size,&buffer))){release(sample);break;}
  ((HRESULT(WINAPI*)(void*,void*))VT(sample,42))(sample,buffer);
  OutputBuffer ob;memset(&ob,0,sizeof(ob));ob.sample=sample;DWORD status=0;
  HRESULT hr=((HRESULT(WINAPI*)(void*,DWORD,DWORD,OutputBuffer*,DWORD*))VT(mft,25))(mft,0,1,&ob,&status);
  if(ob.events)release(ob.events);
  if(hr==S_OK){
   DWORD length=0;((HRESULT(WINAPI*)(void*,DWORD*))VT(buffer,5))(buffer,&length);
   bytes+=length;(*packets)++;
  }
  release(buffer);release(sample);
  if(hr!=S_OK)break;
 }
 return bytes;
}
static void encode_test(void *activate,const char *label){
 const UINT32 w=1280,h=720,bitrate=5000000;
 void *mft=NULL,*out_type=NULL,*in_type=NULL;
 HRESULT hr=((HRESULT(WINAPI*)(void*,const GUID*,void**))VT(activate,33))(activate,&IID_IMFTransform,&mft);
 if(FAILED(hr)){say("%s: no se pudo activar 0x%08lx",label,(unsigned long)hr);return;}
 out_type=video_type(&MFVideoFormat_H264,w,h);in_type=video_type(&MFVideoFormat_NV12,w,h);
 if(!out_type||!in_type){say("%s: MFCreateMediaType fallo",label);goto done;}
 SET_U32(out_type,MF_MT_AVG_BITRATE,bitrate);
 hr=((HRESULT(WINAPI*)(void*,DWORD,void*,DWORD))VT(mft,16))(mft,0,out_type,0);
 if(FAILED(hr)){say("%s: SetOutputType fallo 0x%08lx",label,(unsigned long)hr);goto done;}
 hr=((HRESULT(WINAPI*)(void*,DWORD,void*,DWORD))VT(mft,15))(mft,0,in_type,0);
 if(FAILED(hr)){say("%s: SetInputType fallo 0x%08lx",label,(unsigned long)hr);goto done;}
 StreamInfo si;memset(&si,0,sizeof(si));
 ((HRESULT(WINAPI*)(void*,DWORD,StreamInfo*))VT(mft,7))(mft,0,&si);
 DWORD out_size=si.size?si.size:w*h;
 ((HRESULT(WINAPI*)(void*,UINT,ULONG_PTR))VT(mft,23))(mft,0x10000000,0); /* BEGIN_STREAMING */
 ((HRESULT(WINAPI*)(void*,UINT,ULONG_PTR))VT(mft,23))(mft,0x10000003,0); /* START_OF_STREAM */
 const DWORD frame_size=w*h*3/2;
 const int total=60;int packets=0,first_packet=-1;size_t bytes=0;double busy=0;
 for(int f=0;f<total;f++){
  void *sample=NULL,*buffer=NULL;BYTE *data=NULL;DWORD max=0,cur=0;
  if(FAILED(mf_sample(&sample))||FAILED(mf_buffer(frame_size,&buffer))){release(sample);say("%s: sin memoria",label);break;}
  ((HRESULT(WINAPI*)(void*,BYTE**,DWORD*,DWORD*))VT(buffer,3))(buffer,&data,&max,&cur);
  /* Imagen sintetica con movimiento para que el codificador trabaje de verdad. */
  for(UINT32 y=0;y<h;y++)for(UINT32 x=0;x<w;x++)data[y*w+x]=(BYTE)((x+y*2+f*7)^(x>>3));
  memset(data+w*h,128+(f&15),w*h/2);
  ((HRESULT(WINAPI*)(void*))VT(buffer,4))(buffer);
  ((HRESULT(WINAPI*)(void*,DWORD))VT(buffer,6))(buffer,frame_size);
  ((HRESULT(WINAPI*)(void*,void*))VT(sample,42))(sample,buffer);
  ((HRESULT(WINAPI*)(void*,LONGLONG))VT(sample,36))(sample,(LONGLONG)f*166667);
  ((HRESULT(WINAPI*)(void*,LONGLONG))VT(sample,38))(sample,166667);
  double t=now_ms();
  hr=((HRESULT(WINAPI*)(void*,DWORD,void*,DWORD))VT(mft,24))(mft,0,sample,0);
  int before=packets;
  if(SUCCEEDED(hr))bytes+=drain_output(mft,out_size,&packets);
  busy+=now_ms()-t;
  if(first_packet<0 && packets>before)first_packet=f;
  release(buffer);release(sample);
  if(FAILED(hr)){say("%s: ProcessInput fallo 0x%08lx en la imagen %d",label,(unsigned long)hr,f);break;}
 }
 ((HRESULT(WINAPI*)(void*,UINT,ULONG_PTR))VT(mft,23))(mft,1,0); /* DRAIN */
 bytes+=drain_output(mft,out_size,&packets);
 say("%s: %d imagenes 1280x720 en %.1f ms (%.2f ms por imagen), %d paquetes, %.2f Mbit/s, primer paquete tras %d imagenes",
  label,total,busy,busy/total,packets,bytes*8.0*60.0/total/1e6,first_packet<0?-1:first_packet+1);
done:
 release(in_type);release(out_type);
 ((HRESULT(WINAPI*)(void*))VT(activate,34))(activate);
 release(mft);
}
static void probe_media(void){
 HMODULE mfplat=LoadLibraryW(L"mfplat.dll"),ole=LoadLibraryW(L"ole32.dll");
 if(!mfplat){say("Media Foundation: mfplat.dll no existe (Windows N sin Media Feature Pack)");return;}
 typedef HRESULT (WINAPI *Startup)(ULONG,DWORD);typedef HRESULT (WINAPI *Shutdown)(void);
 Startup startup=(Startup)GetProcAddress(mfplat,"MFStartup");
 Shutdown shutdown=(Shutdown)GetProcAddress(mfplat,"MFShutdown");
 mft_enum=(EnumMft)GetProcAddress(mfplat,"MFTEnumEx");
 mf_type=(CreateType)GetProcAddress(mfplat,"MFCreateMediaType");
 mf_sample=(CreateSample)GetProcAddress(mfplat,"MFCreateSample");
 mf_buffer=(CreateBuffer)GetProcAddress(mfplat,"MFCreateMemoryBuffer");
 task_free=ole?(void(WINAPI*)(void*))GetProcAddress(ole,"CoTaskMemFree"):NULL;
 if(!startup||!shutdown||!mft_enum||!mf_type||!mf_sample||!mf_buffer||!task_free){say("Media Foundation: faltan funciones");return;}
 HRESULT hr=startup(0x00020070,0);
 if(FAILED(hr)){say("Media Foundation: MFStartup fallo 0x%08lx",(unsigned long)hr);return;}
 TypeInfo nv12={MFMediaType_Video,MFVideoFormat_NV12},h264={MFMediaType_Video,MFVideoFormat_H264};
 void *software=NULL;
 list_mfts(&MFT_CATEGORY_VIDEO_ENCODER,0x04|0x40,&nv12,&h264,"Codificadores H.264 por hardware",NULL);
 list_mfts(&MFT_CATEGORY_VIDEO_ENCODER,0x01|0x40,&nv12,&h264,"Codificadores H.264 por software",&software);
 list_mfts(&MFT_CATEGORY_VIDEO_DECODER,0x01|0x02|0x04|0x40,&h264,&nv12,"Decodificadores H.264",NULL);
 if(software){encode_test(software,"Prueba de codificacion por software");release(software);}
 else say("Prueba de codificacion: no hay codificador por software");
 shutdown();
}

/* ---------- Winsock ---------- */
typedef struct { short family; unsigned short port; unsigned long addr; char zero[8]; } Addr4;
static void probe_socket(void){
 HMODULE ws=LoadLibraryW(L"ws2_32.dll");
 if(!ws){say("Winsock: ws2_32.dll no disponible");return;}
 typedef int (WINAPI *Startup)(WORD,void*);typedef int (WINAPI *Cleanup)(void);
 typedef UINT_PTR (WINAPI *Socket)(int,int,int);typedef int (WINAPI *Bind)(UINT_PTR,const void*,int);
 typedef int (WINAPI *Name)(UINT_PTR,void*,int*);typedef int (WINAPI *SendTo)(UINT_PTR,const char*,int,int,const void*,int);
 typedef int (WINAPI *Recv)(UINT_PTR,char*,int,int);typedef int (WINAPI *Close)(UINT_PTR);
 typedef int (WINAPI *Opt)(UINT_PTR,int,int,const char*,int);
 Startup startup=(Startup)GetProcAddress(ws,"WSAStartup");Cleanup cleanup=(Cleanup)GetProcAddress(ws,"WSACleanup");
 Socket sock=(Socket)GetProcAddress(ws,"socket");Bind bind_=(Bind)GetProcAddress(ws,"bind");
 Name name=(Name)GetProcAddress(ws,"getsockname");SendTo sendto_=(SendTo)GetProcAddress(ws,"sendto");
 Recv recv_=(Recv)GetProcAddress(ws,"recv");Close close=(Close)GetProcAddress(ws,"closesocket");
 Opt opt=(Opt)GetProcAddress(ws,"setsockopt");
 char data[512];
 if(!startup||startup(0x0202,data)!=0){say("Winsock: WSAStartup fallo");return;}
 /* Solo la interfaz local: no abre puertos ni provoca avisos del cortafuegos. */
 UINT_PTR a=sock(2,2,17),b=sock(2,2,17);
 Addr4 la;memset(&la,0,sizeof(la));la.family=2;la.addr=0x0100007fUL; /* 127.0.0.1 en orden de red */
 Addr4 lb=la;int len=sizeof(lb);
 int timeout=200;
 if(a==(UINT_PTR)~0||b==(UINT_PTR)~0||bind_(a,&la,sizeof(la))||bind_(b,&lb,sizeof(lb))||name(b,&lb,&len)){
  say("Winsock: no se pudo crear el par UDP local");
 }else{
  opt(b,0xffff,0x1006,(const char*)&timeout,sizeof(timeout)); /* SO_RCVTIMEO */
  char packet[1200];memset(packet,0x5a,sizeof(packet));
  int received=0;double start=now_ms();
  for(int i=0;i<500;i++){
   if(sendto_(a,packet,sizeof(packet),0,&lb,sizeof(lb))==sizeof(packet) && recv_(b,packet,sizeof(packet),0)==sizeof(packet))received++;
  }
  double ms=now_ms()-start;
  say("Winsock: %d de 500 paquetes UDP locales de 1200 bytes en %.1f ms",received,ms);
 }
 if(a!=(UINT_PTR)~0)close(a);if(b!=(UINT_PTR)~0)close(b);
 cleanup();
}

/* ---------- Steam ---------- */
static void probe_steam(void){
 HMODULE steam=GetModuleHandleW(L"steam_api64.dll");
 if(!steam){say("Steam: steam_api64.dll no esta cargada en el juego");return;}
 char path[MAX_PATH];GetModuleFileNameA(steam,path,sizeof(path));
 const char *slash=strrchr(path,'\\');
 say("Steam: %s",slash?slash+1:path);
 typedef int (*GetUser)(void);
 typedef int (*GetPipe)(void);
 typedef void* (*FindIface)(int,const char*);
 typedef uint64_t (*SteamIdFn)(void*);
 typedef const char* (*PersonaFn)(void*);
 typedef int (*LoggedOnFn)(void*);
 GetUser get_user=(GetUser)GetProcAddress(steam,"SteamAPI_GetHSteamUser");
 GetPipe get_pipe=(GetPipe)GetProcAddress(steam,"SteamAPI_GetHSteamPipe");
 FindIface find=(FindIface)GetProcAddress(steam,"SteamInternal_FindOrCreateUserInterface");
 if(!get_user||!find){say("Steam: faltan SteamAPI_GetHSteamUser o SteamInternal_FindOrCreateUserInterface");return;}
 int user=get_user(),pipe=get_pipe?get_pipe():0;
 say("Steam: usuario %d, canal %d%s",user,pipe,user?"":" (Steam no inicializado por el juego)");
 if(!user)return;
 static const char *names[]={"SteamUser020","SteamUser019","SteamFriends017","SteamFriends015",
  "SteamNetworking006","SteamNetworking005","SteamNetworkingMessages002","SteamNetworkingSockets012",
  "SteamNetworkingSockets009","SteamNetworkingSockets008","SteamNetworkingUtils004","SteamNetworkingUtils003","SteamMatchMaking009"};
 void *user_iface=NULL,*friends=NULL;
 char line[1024];size_t at=0;line[0]=0;
 for(size_t i=0;i<sizeof(names)/sizeof(names[0]);i++){
  void *p=find(user,names[i]);
  at+=snprintf(line+at,sizeof(line)-at,"%s%s=%s",i?", ":"",names[i],p?"si":"no");
  if(at>=sizeof(line))at=sizeof(line)-1;
  if(p && !user_iface && !strncmp(names[i],"SteamUser",9))user_iface=p;
  if(p && !friends && !strncmp(names[i],"SteamFriends",12))friends=p;
 }
 say("Steam: interfaces %s",line);
 SteamIdFn steam_id=(SteamIdFn)GetProcAddress(steam,"SteamAPI_ISteamUser_GetSteamID");
 LoggedOnFn logged=(LoggedOnFn)GetProcAddress(steam,"SteamAPI_ISteamUser_BLoggedOn");
 PersonaFn persona=(PersonaFn)GetProcAddress(steam,"SteamAPI_ISteamFriends_GetPersonaName");
 if(user_iface && logged)say("Steam: sesion %s",logged(user_iface)?"conectada":"sin conexion");
 if(user_iface && steam_id)say("Steam: cuenta valida %s",steam_id(user_iface)?"si":"no");
 if(friends && persona){const char *n=persona(friends);say("Steam: perfil %s",n&&*n?"disponible":"sin nombre");}
 static const char *flat[]={"SteamAPI_ISteamNetworking_SendP2PPacket","SteamAPI_ISteamNetworking_ReadP2PPacket",
  "SteamAPI_ISteamNetworking_IsP2PPacketAvailable","SteamAPI_ISteamNetworking_AcceptP2PSessionWithUser",
  "SteamAPI_ISteamFriends_InviteUserToGame","SteamAPI_ISteamFriends_ActivateGameOverlayInviteDialog",
  "SteamAPI_RegisterCallback","SteamAPI_RunCallbacks"};
 at=0;line[0]=0;
 for(size_t i=0;i<sizeof(flat)/sizeof(flat[0]);i++){
  at+=snprintf(line+at,sizeof(line)-at,"%s%s=%s",i?", ":"",flat[i]+9,GetProcAddress(steam,flat[i])?"si":"no");
  if(at>=sizeof(line))at=sizeof(line)-1;
 }
 say("Steam: funciones %s",line);
}

/* ---------- sesion por la red de Steam (fase 1) ----------
 * Solo transporte: Lua decide el protocolo. Cada mensaje lleva un tipo y tres
 * enteros de 64 bits, asi no hace falta pasar cadenas binarias entre Lua y C.
 * Todo se llama desde el hilo del juego (LoopInGameThreadWithDelay). */
#define WIRE_MAGIC0 'L'
#define WIRE_MAGIC1 '2'
#define WIRE_VERSION 1
#define WIRE_SIZE 28
typedef struct { int type; int size; union { uint64_t steam_id; unsigned char raw[128]; } u; } NetIdentity;
typedef struct {
 void *data; int size; unsigned int conn; NetIdentity peer; int64_t conn_user_data;
 int64_t time_received; int64_t message_number; void (*free_data)(void*); void (*release)(void*);
 int channel; int flags; int64_t user_data;
} NetMessage;
static void *steam_friends,*steam_messages;
static uint64_t steam_self,steam_peer;
static unsigned int app_id;
typedef uint64_t (*FlatId)(void*);
typedef int (*FlatCount)(void*,int);
typedef uint64_t (*FlatByIndex)(void*,int,int);
typedef const char* (*FlatName)(void*,uint64_t);
typedef unsigned char (*FlatPlayed)(void*,uint64_t,void*);
static FlatCount friend_count_fn;static FlatByIndex friend_by_index_fn;
static FlatName friend_name_fn;static FlatPlayed friend_played_fn;
/* Cuenta individual del universo publico: 0x0110000100000000 + id de cuenta. */
static int individual(uint64_t id){ return (id>>52)==0x011 && (uint32_t)id!=0; }
static void identity_of(NetIdentity *out,uint64_t id){
 memset(out,0,sizeof(*out));out->type=16;out->size=8;out->u.steam_id=id;
}
static int steam_open(lua_State *L){
 if(steam_messages && steam_self){pushint(L,(long long)steam_self);return 1;}
 HMODULE steam=GetModuleHandleW(L"steam_api64.dll");
 if(!steam){pushbool(L,0);pushstr(L,"steam_api64.dll no esta cargada");return 2;}
 typedef int (*GetUser)(void);typedef void* (*FindIface)(int,const char*);
 GetUser get_user=(GetUser)GetProcAddress(steam,"SteamAPI_GetHSteamUser");
 FindIface find=(FindIface)GetProcAddress(steam,"SteamInternal_FindOrCreateUserInterface");
 FlatId self_id=(FlatId)GetProcAddress(steam,"SteamAPI_ISteamUser_GetSteamID");
 friend_count_fn=(FlatCount)GetProcAddress(steam,"SteamAPI_ISteamFriends_GetFriendCount");
 friend_by_index_fn=(FlatByIndex)GetProcAddress(steam,"SteamAPI_ISteamFriends_GetFriendByIndex");
 friend_name_fn=(FlatName)GetProcAddress(steam,"SteamAPI_ISteamFriends_GetFriendPersonaName");
 friend_played_fn=(FlatPlayed)GetProcAddress(steam,"SteamAPI_ISteamFriends_GetFriendGamePlayed");
 if(!get_user||!find||!self_id||!friend_count_fn||!friend_by_index_fn||!friend_name_fn||!friend_played_fn){
  pushbool(L,0);pushstr(L,"Faltan funciones de Steam");return 2;
 }
 int user=get_user();
 if(!user){pushbool(L,0);pushstr(L,"Steam no esta iniciado en el juego");return 2;}
 void *steam_user=find(user,"SteamUser020");if(!steam_user)steam_user=find(user,"SteamUser019");
 steam_friends=find(user,"SteamFriends017");if(!steam_friends)steam_friends=find(user,"SteamFriends015");
 steam_messages=find(user,"SteamNetworkingMessages002");
 if(!steam_user||!steam_friends||!steam_messages){pushbool(L,0);pushstr(L,"Interfaces de Steam no disponibles");return 2;}
 uint64_t id=self_id(steam_user);
 if(!individual(id)){steam_messages=NULL;pushbool(L,0);pushstr(L,"Cuenta de Steam no valida");return 2;}
 steam_self=id;
 char env[32];DWORD n=GetEnvironmentVariableA("SteamAppId",env,sizeof(env));
 app_id=(n>0&&n<sizeof(env))?(unsigned int)strtoul(env,NULL,10):0;
 if(!app_id)app_id=860510; /* Little Nightmares II en Steam */
 pushint(L,(long long)steam_self);return 1;
}
#define REQUIRE_STEAM(L) if(!steam_messages)return luaerr(L,"La red de Steam no esta abierta")
/* Amigos que estan jugando ahora a Little Nightmares II: id y nombre. */
static uint64_t friend_ids[64];static int friend_total;
static int steam_friends_scan(lua_State *L){
 REQUIRE_STEAM(L);
 friend_total=0;
 int count=friend_count_fn(steam_friends,0x04);
 for(int i=0;i<count && friend_total<64;i++){
  uint64_t id=friend_by_index_fn(steam_friends,i,0x04);
  unsigned char info[32];memset(info,0,sizeof(info));
  if(!individual(id)||!friend_played_fn(steam_friends,id,info))continue;
  if((unsigned int)(*(uint64_t*)info & 0xffffff)!=app_id)continue;
  friend_ids[friend_total++]=id;
 }
 pushint(L,friend_total);return 1;
}
static int steam_friend(lua_State *L){
 REQUIRE_STEAM(L);int valid=0;long long i=toint(L,1,&valid);
 if(!valid||i<1||i>friend_total)return 0;
 uint64_t id=friend_ids[i-1];const char *name=friend_name_fn(steam_friends,id);
 pushint(L,(long long)id);pushstr(L,name&&*name?name:"?");return 2;
}
static int steam_set_peer(lua_State *L){
 REQUIRE_STEAM(L);int valid=0;long long id=toint(L,1,&valid);
 if(!valid)return luaerr(L,"Se esperaba un id de Steam o 0");
 if(steam_peer && (uint64_t)id!=steam_peer){
  NetIdentity who;identity_of(&who,steam_peer);
  ((unsigned char(*)(void*,const NetIdentity*))VT(steam_messages,3))(steam_messages,&who);
 }
 if(id!=0 && !individual((uint64_t)id))return luaerr(L,"Id de Steam no valido");
 steam_peer=(uint64_t)id;pushbool(L,1);return 1;
}
static int steam_send(lua_State *L){
 REQUIRE_STEAM(L);
 if(!steam_peer){pushbool(L,0);return 1;}
 int valid=0;long long values[5];
 for(int i=0;i<5;i++){values[i]=toint(L,i+1,&valid);if(!valid)return luaerr(L,"Se esperaban tipo, tres enteros y fiable");}
 if(values[0]<1||values[0]>255)return luaerr(L,"Tipo de mensaje no valido");
 unsigned char wire[WIRE_SIZE];
 wire[0]=WIRE_MAGIC0;wire[1]=WIRE_MAGIC1;wire[2]=WIRE_VERSION;wire[3]=(unsigned char)values[0];
 memcpy(wire+4,&values[1],8);memcpy(wire+12,&values[2],8);memcpy(wire+20,&values[3],8);
 NetIdentity who;identity_of(&who,steam_peer);
 /* Fiable: 8 | reinicio automatico 32. Sin fiar: sin retraso 5 | reinicio 32. */
 int flags=values[4]?(8|32):(5|32);
 int result=((int(*)(void*,const NetIdentity*,const void*,unsigned int,int,int))VT(steam_messages,0))
  (steam_messages,&who,wire,WIRE_SIZE,flags,0);
 pushbool(L,result==1);pushint(L,result);return 2;
}
/* Devuelve el siguiente mensaje valido del companero: tipo, a, b, c. */
static int steam_receive(lua_State *L){
 REQUIRE_STEAM(L);
 if(steam_peer){
  /* Acepta la peticion pendiente del companero elegido, si la hay. */
  NetIdentity who;identity_of(&who,steam_peer);
  ((unsigned char(*)(void*,const NetIdentity*))VT(steam_messages,2))(steam_messages,&who);
 }
 for(;;){
  NetMessage *msg=NULL;
  int n=((int(*)(void*,int,NetMessage**,int))VT(steam_messages,1))(steam_messages,0,&msg,1);
  if(n<1||!msg)return 0;
  int ok=steam_peer && msg->peer.type==16 && msg->peer.u.steam_id==steam_peer && msg->size==WIRE_SIZE;
  unsigned char wire[WIRE_SIZE];
  if(ok){memcpy(wire,msg->data,WIRE_SIZE);ok=wire[0]==WIRE_MAGIC0&&wire[1]==WIRE_MAGIC1&&wire[2]==WIRE_VERSION;}
  msg->release(msg);
  if(!ok)continue;
  long long a,b,c;memcpy(&a,wire+4,8);memcpy(&b,wire+12,8);memcpy(&c,wire+20,8);
  pushint(L,wire[3]);pushint(L,a);pushint(L,b);pushint(L,c);return 4;
 }
}
/* Estado de la sesion segun Steam: 0 nada, 1 conectando, 2 buscando ruta,
 * 3 conectada, 4 cerrada por el otro, 5 problema local. */
static int steam_state(lua_State *L){
 REQUIRE_STEAM(L);
 if(!steam_peer){pushint(L,0);return 1;}
 static unsigned char info[4096],status[4096];
 NetIdentity who;identity_of(&who,steam_peer);
 int state=((int(*)(void*,const NetIdentity*,void*,void*))VT(steam_messages,5))(steam_messages,&who,info,status);
 pushint(L,state);return 1;
}
static int clock_us(lua_State *L){
 static LARGE_INTEGER freq;LARGE_INTEGER t;
 if(!freq.QuadPart)QueryPerformanceFrequency(&freq);
 QueryPerformanceCounter(&t);
 pushint(L,(long long)(t.QuadPart/freq.QuadPart*1000000+(t.QuadPart%freq.QuadPart)*1000000/freq.QuadPart));return 1;
}

/* ---------- hilo y API Lua ---------- */
static DWORD WINAPI probe_main(void *unused){
 (void)unused;
 typedef HRESULT (WINAPI *CoInit)(void*,DWORD);typedef void (WINAPI *CoUninit)(void);
 HMODULE ole=LoadLibraryW(L"ole32.dll");
 CoInit init=ole?(CoInit)GetProcAddress(ole,"CoInitializeEx"):NULL;
 CoUninit uninit=ole?(CoUninit)GetProcAddress(ole,"CoUninitialize"):NULL;
 HRESULT co=init?init(NULL,0/*MTA*/):E_FAIL;
 double start=now_ms();
 say("%s",ONLINE_VERSION);
 probe_system();
 probe_capture();
 probe_media();
 probe_socket();
 probe_steam();
 say("Diagnostico terminado en %.0f ms",now_ms()-start);
 if(SUCCEEDED(co)&&uninit)uninit();
 InterlockedExchange(&probe_state,2);
 return 0;
}
static int probe_start(lua_State *L){
 if(InterlockedCompareExchange(&probe_state,1,0)!=0){pushbool(L,0);return 1;}
 report_len=0;report[0]=0;
 probe_thread=CreateThread(NULL,0,probe_main,NULL,0,NULL);
 if(!probe_thread){InterlockedExchange(&probe_state,0);return luaerr(L,"No se pudo crear el hilo del diagnostico");}
 pushbool(L,1);return 1;
}
static int probe_poll(lua_State *L){
 if(probe_state!=2)return 0;
 if(probe_thread){WaitForSingleObject(probe_thread,INFINITE);CloseHandle(probe_thread);probe_thread=NULL;}
 pushstr(L,report);
 InterlockedExchange(&probe_state,0);
 return 1;
}
static void field(lua_State *L,const char *name,LuaFn fn){pushfn(L,fn,0);setfield(L,-2,name);}
static int identity(unsigned char *base,unsigned long timestamp,unsigned long image_size){
 MEMORY_BASIC_INFORMATION m;
 if(!base || !VirtualQuery(base,&m,sizeof(m)) || m.State!=MEM_COMMIT || *(unsigned short*)base!=0x5a4d)return 0;
 unsigned long off=*(unsigned long*)(base+60);
 if(off>3500 || *(unsigned long*)(base+off)!=0x4550)return 0;
 return *(unsigned long*)(base+off+8)==timestamp && *(unsigned long*)(base+off+24+56)==image_size;
}
__declspec(dllexport) int luaopen_ln2_online(lua_State *L){
 unsigned char *runtime=(unsigned char*)GetModuleHandleW(L"UE4SS.dll");
 /* Sin la version exacta de UE4SS las direcciones de Lua no son validas. */
 if(!identity(runtime,UE4SS_TIMESTAMP,UE4SS_IMAGE_SIZE))return 0;
 #define API(name,variable) variable=(void*)(runtime+RVA_##name)
 API(lua_pushboolean,pushbool);API(lua_pushinteger,pushint);API(lua_tointegerx,toint);API(lua_pushstring,pushstr);API(lua_pushcclosure,pushfn);
 API(lua_createtable,newtable);API(lua_setfield,setfield);API(luaL_error,luaerr);
 newtable(L,0,11);
 field(L,"probe_start",probe_start);
 field(L,"probe_poll",probe_poll);
 field(L,"steam_open",steam_open);
 field(L,"friends_scan",steam_friends_scan);
 field(L,"friend",steam_friend);
 field(L,"set_peer",steam_set_peer);
 field(L,"send",steam_send);
 field(L,"receive",steam_receive);
 field(L,"session_state",steam_state);
 field(L,"clock_us",clock_us);
 pushstr(L,ONLINE_VERSION);setfield(L,-2,"version");
 return 1;
}
